import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:trip_together/services/auth_state.dart';
import 'package:trip_together/services/api_exception.dart';
import 'package:trip_together/services/hotel_api.dart';
import 'package:trip_together/models/hotel_search_models.dart';

class EventDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(event['title'] ?? 'Szczegóły wycieczki'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.directions_car), text: 'Transport'),
              Tab(icon: Icon(Icons.hotel), text: 'Nocleg'),
              Tab(icon: Icon(Icons.local_activity), text: 'Atrakcje'),
              Tab(icon: Icon(Icons.event_available), text: 'Plan'),
              Tab(icon: Icon(Icons.chat), text: 'Czat'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const TransportSearchView(),
            const AccommodationSearchView(),
            AttractionsSearchView(
              eventId: event['id'].toString(),
              initialCity: event['destination_city'] ?? '',
            ),
            ItineraryView(eventId: event['id'].toString()),
            const Center(child: Text('Czat wydarzenia')),
          ],
        ),
      ),
    );
  }
}

class ItineraryView extends StatefulWidget {
  final String eventId;

  const ItineraryView({super.key, required this.eventId});

  @override
  State<ItineraryView> createState() => _ItineraryViewState();
}

class _ItineraryViewState extends State<ItineraryView> {
  List<dynamic> _items = [];
  bool _isLoading = true;
  String? _errorMessage;

  String get _baseUrl {
    return kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';
  }

  @override
  void initState() {
    super.initState();
    _fetchItinerary();
  }

  Future<void> _fetchItinerary() async {
    final authState = Provider.of<AuthState>(context, listen: false);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/events/${widget.eventId}/itinerary/'),
        headers: {
          if (authState.token != null) "Authorization": "Token ${authState.token}",
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _items = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Błąd pobierania planu: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Błąd połączenia: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteItem(String itemId) async {
    final authState = Provider.of<AuthState>(context, listen: false);

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/v1/events/${widget.eventId}/itinerary/$itemId/'),
        headers: {
          if (authState.token != null) "Authorization": "Token ${authState.token}",
        },
      );

      if (!mounted) return;

      if (response.statusCode == 204) {
        _fetchItinerary(); // Odświeża listę po usunięciu
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usunięto z planu.')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd usuwania: ${response.body}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd połączenia: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)));

    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _fetchItinerary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            Center(child: Text('Plan jest pusty. Dodaj jakieś atrakcje!')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchItinerary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final icon = item['item_type'] == 'ATTRACTION' ? Icons.local_activity : Icons.place;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: Icon(icon, color: Colors.blueAccent),
              title: Text(item['title'] ?? 'Brak nazwy', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(item['item_type'] == 'ATTRACTION' ? 'Atrakcja' : (item['item_type'] ?? '')),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _deleteItem(item['id'].toString()),
                tooltip: 'Usuń z planu',
              ),
            ),
          );
        },
      ),
    );
  }
}

class TransportSearchView extends StatefulWidget {
  const TransportSearchView({super.key});

  @override
  State<TransportSearchView> createState() => _TransportSearchViewState();
}

class _TransportSearchViewState extends State<TransportSearchView> {
  DateTime? _selectedDate;

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TextField(
            decoration: InputDecoration(
              labelText: 'Początek trasy',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Koniec trasy',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Data',
                border: OutlineInputBorder(),
              ),
              child: Text(
                _selectedDate != null
                    ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
                    : 'Wybierz datę',
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('Szukaj transportu'),
            ),
          ),
        ],
      ),
    );
  }
}

class AccommodationSearchView extends StatefulWidget {
  final IHotelApi? hotelApi;

  const AccommodationSearchView({super.key, this.hotelApi});

  @override
  State<AccommodationSearchView> createState() => _AccommodationSearchViewState();
}

class _AccommodationSearchViewState extends State<AccommodationSearchView> {
  late final IHotelApi _hotelApi;
  late final TextEditingController _cityController;
  late final TextEditingController _adultsController;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  DateTime? _checkIn;
  DateTime? _checkOut;
  String? _dateValidationError;

  bool _isLoading = false;

  bool _hasSearched = false;

  List<Hotel> _hotels = const [];
  int _requestSeq = 0;

  String? _lastQ;

  @override
  void initState() {
    super.initState();
    _hotelApi = widget.hotelApi ?? HotelApi(baseUrl: ApiEnvironment.baseUrl);
    _cityController = TextEditingController();
    _adultsController = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _hotelApi.cancelOngoing();
    _cityController.dispose();
    _adultsController.dispose();
    super.dispose();
  }

  String? _fmt(DateTime? date) {
    if (date == null) return null;
    return DateFormat('yyyy-MM-dd').format(date);
  }

  Future<void> _pickCheckIn() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkIn ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _checkIn = picked;
      _validateDates(setStateError: true);
    });
  }

  Future<void> _pickCheckOut() async {
    final initial = _checkOut ?? (_checkIn?.add(const Duration(days: 1)) ?? DateTime.now().add(const Duration(days: 1)));
    final first = _checkIn ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime(2100),
    );
    if (!mounted || picked == null) return;
    setState(() {
      _checkOut = picked;
      _validateDates(setStateError: true);
    });
  }

  bool _validateDates({required bool setStateError}) {
    String? error;
    if (_checkIn != null && _checkOut != null) {
      if (!_checkOut!.isAfter(_checkIn!)) {
        error = 'Check-out must be after check-in.';
      }
    }
    if (setStateError) {
      _dateValidationError = error;
    }
    return error == null;
  }

  int _parseAdults() {
    final raw = _adultsController.text.trim();
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed < 1) return 1;
    return parsed;
  }

  Future<void> _search() async {
    if (_isLoading) return;

    final formOk = _formKey.currentState?.validate() ?? true;
    final datesOk = _validateDates(setStateError: true);
    if (!formOk || !datesOk) {
      setState(() {});
      return;
    }

    final q = _cityController.text.trim();
    if (q.length < 2) {
      // Minimal UX guard even if validator is bypassed.
      return;
    }

    final adults = _parseAdults();
    final checkIn = _fmt(_checkIn);
    final checkOut = _fmt(_checkOut);

    _lastQ = q;

    final requestId = ++_requestSeq;
    setState(() {
      _hasSearched = true;
      _isLoading = true;
      _hotels = const [];
    });

    try {
      final result = await _hotelApi.searchHotels(
        q: q,
        checkIn: checkIn,
        checkOut: checkOut,
        adults: adults,
        limit: 15,
      );

      if (!mounted || requestId != _requestSeq) return;
      setState(() {
        _hotels = result.results;
      });
    } on ApiException catch (e) {
      if (!mounted || requestId != _requestSeq) return;
      _showError(e);
    } catch (e) {
      if (!mounted || requestId != _requestSeq) return;
      _showError(ApiException.unknown(message: e.toString()));
    } finally {
      if (mounted && requestId == _requestSeq) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(ApiException e) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(e.message),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () {
            if (_lastQ == null) return;
            _search();
          },
        ),
      ),
    );
  }

  List<Rate> _topRates(Hotel hotel) {
    final rates = List<Rate>.from(hotel.rates);
    rates.sort((a, b) => (a.perNight ?? a.rate ?? double.infinity).compareTo(b.perNight ?? b.rate ?? double.infinity));
    if (rates.length <= 3) return rates;
    return rates.sublist(0, 3);
  }

  Rate? _cheapestRate(Hotel hotel) {
    final rates = _topRates(hotel);
    if (rates.isEmpty) return null;
    return rates.first;
  }

  Widget _buildRatingStars(double? rating) {
    final value = (rating ?? 0).clamp(0, 5);
    final full = value.floor();
    final hasHalf = (value - full) >= 0.5;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(5, (index) {
        if (index < full) {
          return const Icon(Icons.star, size: 16, color: Colors.amber);
        }
        if (index == full && hasHalf) {
          return const Icon(Icons.star_half, size: 16, color: Colors.amber);
        }
        return const Icon(Icons.star_border, size: 16, color: Colors.amber);
      }),
    );
  }

  Future<void> _openHotelUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid URL.')));
      return;
    }
    final ok = await canLaunchUrl(uri);
    if (!ok) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open link.')));
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildPrices(Hotel hotel) {
    if (hotel.rates.isNotEmpty) {
      final cheapest = _cheapestRate(hotel);
      final offers = _topRates(hotel);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cheapest != null)
            Text(
              'From ${cheapest.perNight ?? cheapest.rate ?? '-'} / night • total ${cheapest.totalForStay ?? '-'}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          const SizedBox(height: 4),
          ...offers.map(
            (r) => Text(
              '${r.name ?? r.code ?? 'Offer'}: ${r.perNight ?? r.rate ?? '-'} / night',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    final pr = hotel.priceRanges;
    if (pr != null && (pr.minimum != null || pr.maximum != null)) {
      return Text('Price range: ${pr.minimum ?? '-'} – ${pr.maximum ?? '-'}');
    }

    return const Text('No prices available');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: 'Hotel search city input',
                  textField: true,
                  child: TextFormField(
                    key: const Key('hotelSearch_city'),
                    controller: _cityController,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_city),
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'City is required.';
                      if (value.length < 2) return 'Enter at least 2 characters.';
                      return null;
                    },
                    onFieldSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        label: 'Hotel search check-in picker',
                        button: true,
                        child: InkWell(
                          key: const Key('hotelSearch_checkIn'),
                          onTap: !_isLoading ? _pickCheckIn : null,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Check-in',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(_fmt(_checkIn) ?? 'Select date'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        label: 'Hotel search check-out picker',
                        button: true,
                        child: InkWell(
                          key: const Key('hotelSearch_checkOut'),
                          onTap: !_isLoading ? _pickCheckOut : null,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Check-out',
                              border: const OutlineInputBorder(),
                              errorText: _dateValidationError,
                            ),
                            child: Text(_fmt(_checkOut) ?? 'Select date'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Semantics(
                  label: 'Hotel search adults input',
                  textField: true,
                  child: TextFormField(
                    key: const Key('hotelSearch_adults'),
                    controller: _adultsController,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Adults',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return null;
                      final parsed = int.tryParse(value);
                      if (parsed == null || parsed < 1) return 'Adults must be >= 1.';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Semantics(
                    label: 'Hotel search submit button',
                    button: true,
                    child: ElevatedButton(
                      key: const Key('hotelSearch_submit'),
                      onPressed: _isLoading ? null : _search,
                      child: const Text('Search hotels'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Builder(
            builder: (context) {
              if (_isLoading) {
                return Semantics(
                  label: 'Hotels loading',
                  child: ListView.builder(
                    itemCount: 6,
                    itemBuilder: (context, index) => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: LinearProgressIndicator(),
                    ),
                  ),
                );
              }

              if (_hasSearched && !_isLoading && _hotels.isEmpty) {
                return const Center(child: Text('No hotels found'));
              }

              if (_hotels.isEmpty) {
                return const Center(child: Text('Search to see hotels'));
              }

              return ListView.builder(
                itemCount: _hotels.length,
                itemBuilder: (context, index) {
                  final hotel = _hotels[index];
                  final rating = hotel.review?.rating;
                  final url = hotel.url;

                  return Semantics(
                    label: 'Hotel search result item',
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    hotel.name,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildRatingStars(rating),
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (hotel.accommodationType != null && hotel.accommodationType!.trim().isNotEmpty)
                              Text(hotel.accommodationType!, style: const TextStyle(color: Colors.black54)),
                            const SizedBox(height: 8),
                            _buildPrices(hotel),
                            if (url != null && url.trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Semantics(
                                  label: 'Open hotel link',
                                  button: true,
                                  child: TextButton(
                                    onPressed: () => _openHotelUrl(url),
                                    child: const Text('Open'),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class AttractionsSearchView extends StatefulWidget {
  final String eventId;
  final String initialCity;

  const AttractionsSearchView({
    super.key,
    required this.eventId,
    required this.initialCity,
  });

  @override
  State<AttractionsSearchView> createState() => _AttractionsSearchViewState();
}

class _AttractionsSearchViewState extends State<AttractionsSearchView> {
  late TextEditingController _cityController;
  List<dynamic> _attractions = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _cityController = TextEditingController(text: widget.initialCity);
    if (widget.initialCity.isNotEmpty) {
      _searchAttractions();
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  String get _baseUrl {
    return kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';
  }

  String _formatKinds(String kinds) {
    if (kinds.isEmpty) return '';
    return kinds.split(',').map((k) {
      final clean = k.trim().replaceAll('_', ' ');
      if (clean.isEmpty) return '';
      return clean[0].toUpperCase() + clean.substring(1);
    }).where((k) => k.isNotEmpty).take(3).join(' • ');
  }

  Future<void> _searchAttractions() async {
    final city = _cityController.text.trim();
    if (city.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _attractions = [];
    });

    final authState = Provider.of<AuthState>(context, listen: false);

    try {
      final encodedCity = Uri.encodeComponent(city);
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/attractions/search/?city=$encodedCity'),
        headers: {
          if (authState.token != null) "Authorization": "Token ${authState.token}",
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        
        List<dynamic> results = [];
        if (decoded is List) {
          results = decoded;
        } else if (decoded is Map) {
          if (decoded.containsKey('data')) {
            results = decoded['data'];
          } else if (decoded.containsKey('features')) {
            results = decoded['features'];
          } else if (decoded.containsKey('results')) {
            results = decoded['results'];
          }
        }

        setState(() {
          _attractions = results;
          if (_attractions.isEmpty) {
            _errorMessage = 'Brak wyników dla tego miasta.';
          }
        });
      } else {
        setState(() {
          _errorMessage = 'Błąd podczas wyszukiwania: ${response.statusCode}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Błąd połączenia: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addToItinerary(dynamic attraction) async {
    final authState = Provider.of<AuthState>(context, listen: false);
    
    final String title = attraction['name'] ?? attraction['title'] ?? 'Nieznana atrakcja';
    final double? lat = attraction['lat'] != null ? (attraction['lat'] as num).toDouble() : null;
    final dynamic rawLon = attraction['lon'] ?? attraction['lng'];
    final double? lon = rawLon != null ? (rawLon as num).toDouble() : null;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/events/${widget.eventId}/itinerary/'),
        headers: {
          "Content-Type": "application/json",
          if (authState.token != null) "Authorization": "Token ${authState.token}",
        },
        body: jsonEncode({
          "title": title,
          "item_type": "ATTRACTION",
          "location_lat": lat,
          "location_lon": lon,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dodano "$title" do planu podróży!')),
        );
      } else {
        String errorMsg = 'Błąd dodawania: ${response.statusCode}';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded.containsKey('detail')) {
            errorMsg = decoded['detail'];
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd połączenia: $e')),
      );
    }
  }

  void _showAttractionDetails(dynamic attraction) {
    final String title = attraction['name'] ?? attraction['title'] ?? 'Nieznana atrakcja';
    final String rawKinds = attraction['kinds'] ?? '';
    final String tags = rawKinds.isNotEmpty ? _formatKinds(rawKinds) : 'Brak tagów';
    final double? lat = attraction['lat'] != null ? (attraction['lat'] as num).toDouble() : null;
    final dynamic rawLon = attraction['lon'] ?? attraction['lng'];
    final double? lon = rawLon != null ? (rawLon as num).toDouble() : null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kategorie:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(tags),
            const SizedBox(height: 8),
            if (lat != null && lon != null)
              Text('Współrzędne:\n$lat, $lon'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Zamknij'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.search),
            label: const Text('Szukaj w Google'),
            onPressed: () async {
              final query = Uri.encodeComponent(title);
              final url = Uri.parse('https://www.google.com/search?q=$query');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } else {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nie można otworzyć linku.')));
              }
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'Miasto',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_city),
                  ),
                  onSubmitted: (_) => _searchAttractions(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _searchAttractions,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
                child: const Text('Szukaj'),
              ),
            ],
          ),
        ),
        if (_isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator())),
        if (!_isLoading && _errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        if (!_isLoading && _attractions.isNotEmpty)
          Expanded(
            child: ListView.builder(
              itemCount: _attractions.length,
              itemBuilder: (context, index) {
                final attraction = _attractions[index];
                final String title = attraction['name'] ?? attraction['title'] ?? 'Nieznana atrakcja';
                final String rawKinds = attraction['kinds'] ?? '';
                final String subtitle = rawKinds.isNotEmpty ? _formatKinds(rawKinds) : (attraction['address'] ?? '');

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.blueAccent,
                      child: Icon(Icons.place, color: Colors.white),
                    ),
                    onTap: () => _showAttractionDetails(attraction),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: subtitle.isNotEmpty 
                        ? Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis) 
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.green, size: 30),
                      onPressed: () => _addToItinerary(attraction),
                      tooltip: 'Dodaj do planu wycieczki',
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
