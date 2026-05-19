import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:trip_together/services/auth_state.dart';

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
  const AccommodationSearchView({super.key});

  @override
  State<AccommodationSearchView> createState() => _AccommodationSearchViewState();
}

class _AccommodationSearchViewState extends State<AccommodationSearchView> {
  DateTimeRange? _selectedDateRange;

  Future<void> _pickDateRange() async {
    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (pickedRange != null) {
      setState(() {
        _selectedDateRange = pickedRange;
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
              labelText: 'Gdzie',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDateRange,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Termin pobytu (od - do)',
                border: OutlineInputBorder(),
              ),
              child: Text(
                _selectedDateRange != null
                    ? '${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start)} - ${DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end)}'
                    : 'Wybierz od kiedy do kiedy',
              ),
            ),
          ),
          const SizedBox(height: 16),
          const TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Liczba osób',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('Szukaj noclegu'),
            ),
          ),
        ],
      ),
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
