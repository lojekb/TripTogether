"""Public transport search using the Transitous (MOTIS 2) API.

Transitous operates a free, key-less MOTIS instance with global public-transport
coverage (https://transitous.org/api/). The endpoint:

  1. geocodes the start/end text to coordinates (``/api/v1/geocode``),
  2. computes public-transport journeys between them (``/api/v5/plan``).

Each journey is returned with its total duration, number of transfers and the
individual legs (train / bus / tram / walk ...), so the frontend can present
real public-transport connections. No API key is required.
"""

from datetime import datetime
from zoneinfo import ZoneInfo

import requests
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

MOTIS_BASE_URL = "https://api.transitous.org"
MAX_JOURNEYS = 6

# MOTIS transport mode -> (Polish label, frontend icon hint).
MODE_LABELS = {
    "WALK": ("Pieszo", "walk"),
    "BIKE": ("Rower", "bike"),
    "CAR": ("Samochód", "car"),
    "TRAM": ("Tramwaj", "tram"),
    "SUBWAY": ("Metro", "subway"),
    "METRO": ("Metro", "subway"),
    "FERRY": ("Prom", "ferry"),
    "AIRPLANE": ("Samolot", "flight"),
    "BUS": ("Autobus", "bus"),
    "COACH": ("Autokar", "bus"),
    "RAIL": ("Pociąg", "train"),
    "HIGHSPEED_RAIL": ("Pociąg (szybki)", "train"),
    "LONG_DISTANCE": ("Pociąg dalekobieżny", "train"),
    "NIGHT_RAIL": ("Pociąg nocny", "train"),
    "REGIONAL_RAIL": ("Pociąg regionalny", "train"),
    "REGIONAL_FAST_RAIL": ("Pociąg regionalny", "train"),
    "SUBURBAN": ("Kolej miejska", "train"),
    "FUNICULAR": ("Kolejka", "train"),
    "AERIAL_LIFT": ("Kolejka linowa", "train"),
}


def geocode(query, timeout=10):
    """Resolve a place name to {coords: [lon, lat], label} using MOTIS geocode."""
    try:
        resp = requests.get(
            f"{MOTIS_BASE_URL}/api/v1/geocode",
            params={"text": query},
            timeout=timeout,
        )
        if resp.status_code != 200:
            return None
        matches = resp.json()
        if not isinstance(matches, list) or not matches:
            return None
        best = matches[0]
        lat, lon = best.get("lat"), best.get("lon")
        if lat is None or lon is None:
            return None
        return {"coords": [lon, lat], "label": best.get("name", query)}
    except requests.RequestException:
        return None


def plan(start, end, when, timeout=20):
    """Return the list of transit itineraries between two [lon, lat] points."""
    params = {
        # MOTIS expects "latitude,longitude" tuples.
        "fromPlace": f"{start[1]},{start[0]}",
        "toPlace": f"{end[1]},{end[0]}",
        "arriveBy": "false",
    }
    if when:
        params["time"] = when
    try:
        resp = requests.get(
            f"{MOTIS_BASE_URL}/api/v5/plan",
            params=params,
            timeout=timeout,
        )
        if resp.status_code != 200:
            return None
        return resp.json().get("itineraries", []) or []
    except requests.RequestException:
        return None


def format_duration(seconds):
    total_minutes = int(round((seconds or 0) / 60))
    hours, minutes = divmod(total_minutes, 60)
    if hours and minutes:
        return f"{hours} h {minutes} min"
    if hours:
        return f"{hours} h"
    return f"{minutes} min"


def format_time(iso_value, tz_name=None):
    """Format an RFC3339 timestamp to local 'HH:MM' (using the stop timezone)."""
    if not iso_value:
        return None
    try:
        dt = datetime.fromisoformat(iso_value.replace("Z", "+00:00"))
        if tz_name:
            dt = dt.astimezone(ZoneInfo(tz_name))
        return dt.strftime("%H:%M")
    except (ValueError, KeyError):
        return None


def build_leg(leg):
    mode = leg.get("mode", "OTHER")
    label, icon = MODE_LABELS.get(mode, ("Inny środek", "transit"))
    frm = leg.get("from", {}) or {}
    to = leg.get("to", {}) or {}
    line = leg.get("displayName") or leg.get("routeShortName") or leg.get("routeLongName")
    distance = leg.get("distance")
    return {
        "mode": mode,
        "mode_label": label,
        "icon": icon,
        "line": line,
        "headsign": leg.get("headsign"),
        "agency": leg.get("agencyName"),
        "from_name": frm.get("name"),
        "to_name": to.get("name"),
        "departure": format_time(leg.get("startTime"), frm.get("tz")),
        "arrival": format_time(leg.get("endTime"), to.get("tz")),
        "duration_text": format_duration(leg.get("duration")),
        "stops": len(leg.get("intermediateStops") or []),
        "distance_km": round(distance / 1000, 1) if distance else None,
        "departure_track": frm.get("track") or frm.get("scheduledTrack"),
        "arrival_track": to.get("track") or to.get("scheduledTrack"),
        "real_time": bool(leg.get("realTime")),
    }


def build_journey(itinerary):
    raw_legs = itinerary.get("legs", []) or []
    legs = [build_leg(leg) for leg in raw_legs]

    # Summary = list of the public-transport modes used (skip walking transfers).
    transit_labels = []
    for leg in legs:
        if leg["mode"] != "WALK" and leg["mode_label"] not in transit_labels:
            transit_labels.append(leg["mode_label"])
    summary = " • ".join(transit_labels) if transit_labels else "Pieszo"

    # Icon for the journey = first public-transport leg, fallback to walking.
    journey_icon = next((leg["icon"] for leg in legs if leg["mode"] != "WALK"), "walk")

    first = raw_legs[0] if raw_legs else {}
    last = raw_legs[-1] if raw_legs else {}
    departure = format_time(
        first.get("startTime") or itinerary.get("startTime"),
        (first.get("from") or {}).get("tz"),
    )
    arrival = format_time(
        last.get("endTime") or itinerary.get("endTime"),
        (last.get("to") or {}).get("tz"),
    )

    return {
        "summary": summary,
        "icon": journey_icon,
        "duration_minutes": int(round((itinerary.get("duration") or 0) / 60)),
        "duration_text": format_duration(itinerary.get("duration")),
        "transfers": itinerary.get("transfers", 0),
        "departure": departure,
        "arrival": arrival,
        "from_name": (first.get("from") or {}).get("name"),
        "to_name": (last.get("to") or {}).get("name"),
        "legs": legs,
    }


class TransportSearchAPIView(APIView):
    """GET /api/v1/transport/search/?from=...&to=...&date=YYYY-MM-DD

    Returns public-transport journeys (train / bus / tram / metro ...) between two
    locations, each with total duration, number of transfers and individual legs.
    Powered by the free Transitous (MOTIS) API - no API key required.
    """

    permission_classes = [AllowAny]

    def get(self, request):
        origin = request.GET.get("from") or request.GET.get("origin")
        destination = request.GET.get("to") or request.GET.get("destination")
        date = request.GET.get("date")
        # Optional full RFC3339 departure timestamp (incl. timezone offset).
        time = request.GET.get("time")

        if not origin or not destination:
            return Response(
                {"detail": "Parametry 'from' i 'to' są wymagane."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        start = geocode(origin)
        if start is None:
            return Response(
                {"detail": f"Nie znaleziono lokalizacji początkowej: '{origin}'.", "results": []},
                status=status.HTTP_404_NOT_FOUND,
            )
        end = geocode(destination)
        if end is None:
            return Response(
                {"detail": f"Nie znaleziono lokalizacji docelowej: '{destination}'.", "results": []},
                status=status.HTTP_404_NOT_FOUND,
            )

        # Prefer the precise client timestamp; otherwise fall back to 08:00 on the
        # chosen date, or "now" when nothing was provided.
        when = time or (f"{date}T08:00:00Z" if date else None)
        itineraries = plan(start["coords"], end["coords"], when)
        if itineraries is None:
            return Response(
                {"detail": "Usługa transportu publicznego jest chwilowo niedostępna."},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        results = [build_journey(it) for it in itineraries[:MAX_JOURNEYS]]

        meta = {
            "from": start["label"],
            "to": end["label"],
            "from_coords": start["coords"],
            "to_coords": end["coords"],
            "date": date,
            "count": len(results),
        }

        return Response({"meta": meta, "results": results}, status=status.HTTP_200_OK)
