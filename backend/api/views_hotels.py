from django.conf import settings
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import AllowAny
import http.client
import json
from datetime import datetime
from concurrent.futures import ThreadPoolExecutor, wait

RAPIDAPI_KEY = getattr(settings, "RAPIDAPI_KEY", None)
RAPIDAPI_HOST = "xotelo-hotel-prices.p.rapidapi.com"
XOTELO_HOST = "data.xotelo.com"


def search_location(query):
    conn = http.client.HTTPSConnection(RAPIDAPI_HOST, timeout=10)
    headers = {}
    if RAPIDAPI_KEY:
        headers = {
            "x-rapidapi-key": RAPIDAPI_KEY,
            "x-rapidapi-host": RAPIDAPI_HOST,
        }
    try:
        conn.request("GET", f"/api/search?query={query}&location_type=geo", headers=headers)
        res = conn.getresponse()
        raw = res.read().decode("utf-8") or "{}"
        data = json.loads(raw)
    except Exception:
        data = {}
    finally:
        try:
            conn.close()
        except Exception:
            pass
    return data.get("result", {}).get("list", [])


def get_hotels(location_key, limit=15):
    conn = http.client.HTTPSConnection(XOTELO_HOST, timeout=10)
    data = {}
    try:
        conn.request("GET", f"/api/list?location_key={location_key}&limit={limit}&sort=best_value")
        res = conn.getresponse()
        raw = res.read().decode("utf-8") or "{}"
        data = json.loads(raw)
    except Exception:
        data = {}
    finally:
        try:
            conn.close()
        except Exception:
            pass
    if not data:
        return []
    return data.get("result", {}).get("list", [])


def get_rates(hotel_key, chk_in, chk_out, adults=1, currency="USD", retries=2, timeout=6):
    for attempt in range(retries):
        try:
            conn = http.client.HTTPSConnection(XOTELO_HOST, timeout=timeout)
            conn.request(
                "GET",
                f"/api/rates?hotel_key={hotel_key}&chk_in={chk_in}&chk_out={chk_out}&adults={adults}&currency={currency}",
            )
            res = conn.getresponse()
            raw = res.read().decode("utf-8") or "{}"
            data = json.loads(raw)
            try:
                conn.close()
            except Exception:
                pass
            if not data:
                return []
            return data.get("result", {}).get("rates", []) or []
        except Exception:
            try:
                conn.close()
            except Exception:
                pass
            if attempt == retries - 1:
                return []


class HotelSearchAPIView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        q = request.GET.get("q") or request.GET.get("city")
        if not q:
            return Response({"detail": "Missing query parameter 'q' or 'city'."}, status=status.HTTP_400_BAD_REQUEST)

        check_in = request.GET.get("check_in")
        check_out = request.GET.get("check_out")
        try:
            check_in_dt = datetime.fromisoformat(check_in).date() if check_in else None
            check_out_dt = datetime.fromisoformat(check_out).date() if check_out else None
        except Exception:
            return Response({"detail": "Invalid date format."}, status=400)

        adults = int(request.GET.get("adults", "1"))
        limit = int(request.GET.get("limit", "15"))

        locations = search_location(q)
        if not locations:
            return Response({"detail": "No locations found.", "results": []}, status=status.HTTP_200_OK)

        loc = locations[0]
        location_key = loc.get("location_key") or loc.get("hotel_key", "").split("-")[0]
        hotels = get_hotels(location_key, limit=limit)
        if not hotels:
            return Response({"detail": "No hotels found for this location.", "results": []}, status=status.HTTP_200_OK)

        results_map = {}

        def fetch(h):
            return h, get_rates(h["key"], check_in, check_out, adults=adults, timeout=6)

        with ThreadPoolExecutor(max_workers=8) as executor:
            futures = {executor.submit(fetch, h): h for h in hotels}
            done, not_done = wait(futures.keys(), timeout=12)
            for future in done:
                try:
                    hotel, rates = future.result()
                except Exception:
                    hotel, rates = futures[future], []
                results_map[hotel["key"]] = {"hotel": hotel, "rates": rates}
            for future in not_done:
                try:
                    future.cancel()
                except Exception:
                    pass
                hotel = futures.get(future)
                if hotel:
                    results_map[hotel["key"]] = {"hotel": hotel, "rates": []}

        ordered = [results_map[h["key"]] for h in hotels]

        output = []
        for item in ordered:
            h = item["hotel"]
            rates = item["rates"]
            entry = {
                "key": h.get("key"),
                "name": h.get("name"),
                "accommodation_type": h.get("accommodation_type"),
                "review": h.get("review_summary", {}),
                "mentions": h.get("mentions", []),
                "merchandising_labels": h.get("merchandising_labels", []),
                "price_ranges": h.get("price_ranges", {}),
                "url": h.get("url", ""),
                "rates": rates,
            }
            if rates:
                for r in entry["rates"]:
                    if r.get("rate") is not None and check_in and check_out:
                        try:
                            nights = (check_out_dt - check_in_dt).days
                            r["per_night"] = r["rate"]
                            r["total_for_stay"] = r["rate"] * nights
                        except Exception:
                            pass
            output.append(entry)

        meta = {
            "location": loc.get("place_name") or loc.get("short_place_name") or q,
            "check_in": check_in,
            "check_out": check_out,
            "nights": (check_out_dt - check_in_dt).days if check_in and check_out else None,
            "adults": adults,
            "count": len(output),
        }

        return Response({"meta": meta, "results": output}, status=status.HTTP_200_OK)
