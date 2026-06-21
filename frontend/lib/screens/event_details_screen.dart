import 'dart:async';
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
import 'package:trip_together/services/transport_api.dart';
import 'package:trip_together/models/transport_search_models.dart';
import 'package:trip_together/screens/members_screen.dart';

class EventDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final eventId = event['id'].toString();
    final canContribute = event['can_contribute'] == true;
    final canManageRoles = event['can_manage_roles'] == true;

    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: Text(event['title'] ?? 'Szczegóły wycieczki'),
          actions: [
            IconButton(
              icon: const Icon(Icons.group),
              tooltip: canManageRoles ? 'Zarządzaj rolami' : 'Uczestnicy',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MembersScreen(
                      eventId: eventId,
                      eventTitle: event['title'] ?? '',
                      canManageRoles: canManageRoles,
                      currentUserRole: event['my_role'] as String?,
                    ),
                  ),
                );
              },
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.directions_car), text: 'Transport'),
              Tab(icon: Icon(Icons.hotel), text: 'Nocleg'),
              Tab(icon: Icon(Icons.local_activity), text: 'Atrakcje'),
              Tab(icon: Icon(Icons.event_available), text: 'Plan'),
              Tab(icon: Icon(Icons.how_to_vote), text: 'Ankiety'),
              Tab(icon: Icon(Icons.chat), text: 'Czat'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (!canContribute) const _ReadOnlyBanner(),
            Expanded(
              child: TabBarView(
                children: [
                  TransportSearchView(
                    initialTo: event['destination_city'] ?? '',
                    eventId: eventId,
                    canContribute: canContribute,
                  ),
                  const AccommodationSearchView(),
                  AttractionsSearchView(
                    eventId: eventId,
                    initialCity: event['destination_city'] ?? '',
                    canContribute: canContribute,
                  ),
                  ItineraryView(eventId: eventId, canContribute: canContribute),
                  PollsView(
                    eventId: eventId,
                    destinationCity: event['destination_city'] ?? '',
                    canContribute: canContribute,
                  ),
                  ChatView(eventId: eventId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyBanner extends StatelessWidget {
  const _ReadOnlyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF3E0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: const [
          Icon(Icons.lock_outline, size: 18, color: Color(0xFFE65100)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Masz rolę „Członek” – możesz przeglądać, głosować i pisać na czacie, '
              'ale nie możesz dodawać treści. Poproś organizatora o rolę „Uprawniony”.',
              style: TextStyle(fontSize: 12, color: Color(0xFFE65100)),
            ),
          ),
        ],
      ),
    );
  }
}

class ItineraryView extends StatefulWidget {
  final String eventId;
  final bool canContribute;

  const ItineraryView({super.key, required this.eventId, this.canContribute = true});

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

  Future<void> _confirmDelete(String itemId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usunąć z planu?'),
        content: Text('Czy na pewno chcesz usunąć "$title" z planu wycieczki?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Usuń', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteItem(itemId);
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
          final type = item['item_type'] as String?;
          final description = (item['description'] as String?)?.trim() ?? '';

          IconData icon;
          String typeLabel;
          switch (type) {
            case 'ATTRACTION':
              icon = Icons.local_activity;
              typeLabel = 'Atrakcja';
              break;
            case 'HOTEL':
              icon = Icons.hotel;
              typeLabel = 'Nocleg';
              break;
            case 'FLIGHT':
              icon = Icons.flight;
              typeLabel = 'Transport (lot)';
              break;
            case 'OTHER':
              icon = Icons.directions_transit;
              typeLabel = 'Transport';
              break;
            default:
              icon = Icons.place;
              typeLabel = type ?? '';
          }

          final subtitleText = description.isNotEmpty ? '$typeLabel\n$description' : typeLabel;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              isThreeLine: description.isNotEmpty,
              leading: Icon(icon, color: Colors.blueAccent),
              title: Text(item['title'] ?? 'Brak nazwy', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(subtitleText),
              trailing: widget.canContribute
                  ? IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDelete(item['id'].toString(), item['title'] ?? 'ten element'),
                      tooltip: 'Usuń z planu',
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class TransportSearchView extends StatefulWidget {
  final ITransportApi? transportApi;
  final String? initialTo;
  final String? eventId;
  final bool canContribute;

  const TransportSearchView({super.key, this.transportApi, this.initialTo, this.eventId, this.canContribute = true});

  @override
  State<TransportSearchView> createState() => _TransportSearchViewState();
}

class _TransportSearchViewState extends State<TransportSearchView> {
  late final ITransportApi _transportApi;
  late final TextEditingController _fromController;
  late final TextEditingController _toController;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;
  bool _hasSearched = false;

  List<Journey> _journeys = const [];
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _transportApi = widget.transportApi ?? TransportApi(baseUrl: ApiEnvironment.baseUrl);
    _fromController = TextEditingController();
    _toController = TextEditingController(text: widget.initialTo ?? '');
  }

  @override
  void dispose() {
    _transportApi.cancelOngoing();
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  String get _baseUrl => kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';

  String? _fmt(DateTime? date) {
    if (date == null) return null;
    return DateFormat('yyyy-MM-dd').format(date);
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  String? _fmtTime(TimeOfDay? time) {
    if (time == null) return null;
    return '${_two(time.hour)}:${_two(time.minute)}';
  }

  /// Build an RFC3339 timestamp (with the device timezone offset) for MOTIS.
  String _toRfc3339(DateTime local) {
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final oh = _two(offset.inHours.abs());
    final om = _two(offset.inMinutes.abs() % 60);
    return '${local.year.toString().padLeft(4, '0')}-${_two(local.month)}-${_two(local.day)}'
        'T${_two(local.hour)}:${_two(local.minute)}:00$sign$oh:$om';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedTime = picked);
  }

  IconData _iconFor(String? icon) {
    switch (icon) {
      case 'car':
        return Icons.directions_car;
      case 'bike':
        return Icons.directions_bike;
      case 'walk':
        return Icons.directions_walk;
      case 'train':
        return Icons.train;
      case 'bus':
        return Icons.directions_bus;
      case 'tram':
        return Icons.tram;
      case 'subway':
        return Icons.subway;
      case 'ferry':
        return Icons.directions_boat;
      case 'flight':
        return Icons.flight;
      default:
        return Icons.alt_route;
    }
  }

  Future<void> _search() async {
    if (_isLoading) return;

    final formOk = _formKey.currentState?.validate() ?? true;
    if (!formOk) {
      setState(() {});
      return;
    }

    final from = _fromController.text.trim();
    final to = _toController.text.trim();

    final requestId = ++_requestSeq;
    setState(() {
      _hasSearched = true;
      _isLoading = true;
      _journeys = const [];
    });

    String? departureIso;
    if (_selectedDate != null || _selectedTime != null) {
      final d = _selectedDate ?? DateTime.now();
      final t = _selectedTime ?? const TimeOfDay(hour: 8, minute: 0);
      departureIso = _toRfc3339(DateTime(d.year, d.month, d.day, t.hour, t.minute));
    }

    try {
      final result = await _transportApi.searchTransport(
        from: from,
        to: to,
        date: _fmt(_selectedDate),
        time: departureIso,
      );

      if (!mounted || requestId != _requestSeq) return;
      setState(() => _journeys = result.results);
    } on ApiException catch (e) {
      if (!mounted || requestId != _requestSeq) return;
      _showError(e);
    } catch (e) {
      if (!mounted || requestId != _requestSeq) return;
      _showError(ApiException.unknown(message: e.toString()));
    } finally {
      if (mounted && requestId == _requestSeq) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(ApiException e) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(e.message),
        action: SnackBarAction(label: 'Ponów', onPressed: _search),
      ),
    );
  }

  Future<void> _openInMaps() async {
    final from = Uri.encodeComponent(_fromController.text.trim());
    final to = Uri.encodeComponent(_toController.text.trim());
    if (from.isEmpty || to.isEmpty) return;
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&origin=$from&destination=$to&travelmode=transit',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nie można otworzyć map.')));
    }
  }

  String _journeyTitle(Journey journey) {
    final from = (journey.fromName ?? '').trim().isNotEmpty
        ? journey.fromName!.trim()
        : _fromController.text.trim();
    final to = (journey.toName ?? '').trim().isNotEmpty
        ? journey.toName!.trim()
        : _toController.text.trim();
    final dep = journey.departure != null ? ' (${journey.departure})' : '';
    return '$from → $to$dep';
  }

  String _journeyDescription(Journey journey) {
    final buffer = StringBuffer();
    final transfers = journey.transfers == 0
        ? 'bez przesiadek'
        : '${journey.transfers} ${_transfersLabel(journey.transfers)}';
    buffer.writeln(
      [
        if (journey.summary.isNotEmpty) journey.summary,
        if (journey.durationText != null) journey.durationText!,
        transfers,
      ].join(' • '),
    );
    for (final leg in journey.legs) {
      final line = (leg.line != null && leg.line!.trim().isNotEmpty) ? ' ${leg.line}' : '';
      final times = [
        if (leg.departure != null) leg.departure!,
        if (leg.arrival != null) leg.arrival!,
      ].join('–');
      final timePart = times.isNotEmpty ? ' ($times)' : '';
      buffer.writeln('• ${leg.modeLabel}$line: ${leg.fromName ?? '?'} → ${leg.toName ?? '?'}$timePart');
    }
    return buffer.toString().trim();
  }

  Future<void> _saveJourney(Journey journey) async {
    final eventId = widget.eventId;
    if (eventId == null) return;

    final authState = Provider.of<AuthState>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final title = _journeyTitle(journey);
    final itemType = journey.legs.any((l) => l.mode == 'AIRPLANE') ? 'FLIGHT' : 'OTHER';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/events/$eventId/itinerary/'),
        headers: {
          'Content-Type': 'application/json',
          if (authState.token != null) 'Authorization': 'Token ${authState.token}',
        },
        body: jsonEncode({
          'title': title,
          'description': _journeyDescription(journey),
          'item_type': itemType,
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        messenger.showSnackBar(SnackBar(content: Text('Zapisano połączenie do planu: $title')));
      } else {
        String msg = 'Błąd zapisu: ${response.statusCode}';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['detail'] is String) msg = decoded['detail'] as String;
        } catch (_) {}
        messenger.showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Błąd połączenia: $e')));
    }
  }

  Widget _buildJourneyCard(Journey journey) {
    final stations = [
      if (journey.fromName != null) journey.fromName!,
      if (journey.toName != null) journey.toName!,
    ].join(' → ');

    final timeWindow = [
      if (journey.departure != null) journey.departure!,
      if (journey.arrival != null) journey.arrival!,
    ].join(' → ');

    final infoLine = [
      if (timeWindow.isNotEmpty) timeWindow,
      if (journey.durationText != null) journey.durationText!,
      journey.transfers == 0
          ? 'bez przesiadek'
          : '${journey.transfers} ${_transfersLabel(journey.transfers)}',
    ].join(' • ');

    return Semantics(
      label: 'Transport result item',
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: Colors.blueAccent,
            child: Icon(_iconFor(journey.icon), color: Colors.white),
          ),
          title: Text(
            journey.summary.isNotEmpty ? journey.summary : 'Połączenie',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stations.isNotEmpty)
                Text(stations, maxLines: 2, overflow: TextOverflow.ellipsis),
              Text(infoLine, style: const TextStyle(color: Colors.black54)),
            ],
          ),
          children: [
            for (final leg in journey.legs) _buildLegTile(leg),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  if (widget.eventId != null && widget.canContribute)
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.green),
                        label: const Text('Zapisz do planu'),
                        onPressed: () => _saveJourney(journey),
                      ),
                    ),
                  Expanded(
                    child: TextButton.icon(
                      icon: const Icon(Icons.map, size: 18),
                      label: const Text('Mapy Google'),
                      onPressed: _openInMaps,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _transfersLabel(int transfers) {
    if (transfers == 1) return 'przesiadka';
    if (transfers >= 2 && transfers <= 4) return 'przesiadki';
    return 'przesiadek';
  }

  Widget _buildLegTile(JourneyLeg leg) {
    final from = [
      if (leg.departure != null) leg.departure!,
      if (leg.fromName != null) leg.fromName!,
      if (leg.departureTrack != null && leg.departureTrack!.trim().isNotEmpty)
        'peron ${leg.departureTrack}',
    ].join('  ');

    final to = [
      if (leg.arrival != null) leg.arrival!,
      if (leg.toName != null) leg.toName!,
      if (leg.arrivalTrack != null && leg.arrivalTrack!.trim().isNotEmpty)
        'peron ${leg.arrivalTrack}',
    ].join('  ');

    final titleParts = [
      leg.modeLabel,
      if (leg.line != null && leg.line!.trim().isNotEmpty) leg.line!,
    ].join(' ');

    final meta = <String>[
      if (leg.durationText != null) leg.durationText!,
      if (!leg.isWalk && leg.stops > 0) '${leg.stops} ${_stopsLabel(leg.stops)}',
      if (leg.isWalk && leg.distanceKm != null) '${leg.distanceKm} km',
      if (leg.realTime) 'czas rzeczywisty',
    ].join(' • ');

    return ListTile(
      dense: true,
      leading: Icon(
        _iconFor(leg.icon),
        color: leg.isWalk ? Colors.grey : Colors.blueAccent,
      ),
      title: Text(titleParts, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (from.trim().isNotEmpty) Text(from),
          if (to.trim().isNotEmpty) Text(to),
          if (leg.headsign != null && leg.headsign!.trim().isNotEmpty)
            Text('kierunek: ${leg.headsign}', style: const TextStyle(color: Colors.black54)),
          if (leg.agency != null && leg.agency!.trim().isNotEmpty)
            Text(leg.agency!, style: const TextStyle(color: Colors.black54, fontStyle: FontStyle.italic)),
          if (meta.isNotEmpty)
            Text(meta, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }

  String _stopsLabel(int stops) {
    if (stops == 1) return 'przystanek';
    if (stops >= 2 && stops <= 4) return 'przystanki';
    return 'przystanków';
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
                  label: 'Transport search from input',
                  textField: true,
                  child: TextFormField(
                    key: const Key('transportSearch_from'),
                    controller: _fromController,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Początek trasy',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.my_location),
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Podaj początek trasy.';
                      if (value.length < 2) return 'Wpisz co najmniej 2 znaki.';
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Semantics(
                  label: 'Transport search to input',
                  textField: true,
                  child: TextFormField(
                    key: const Key('transportSearch_to'),
                    controller: _toController,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Koniec trasy',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.place),
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Podaj koniec trasy.';
                      if (value.length < 2) return 'Wpisz co najmniej 2 znaki.';
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
                        label: 'Transport search date picker',
                        button: true,
                        child: InkWell(
                          key: const Key('transportSearch_date'),
                          onTap: !_isLoading ? _pickDate : null,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Data',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(_fmt(_selectedDate) ?? 'Wybierz datę'),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        label: 'Transport search time picker',
                        button: true,
                        child: InkWell(
                          key: const Key('transportSearch_time'),
                          onTap: !_isLoading ? _pickTime : null,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Godzina odjazdu',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.schedule),
                            ),
                            child: Text(_fmtTime(_selectedTime) ?? 'Wybierz godzinę'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Semantics(
                    label: 'Transport search submit button',
                    button: true,
                    child: ElevatedButton(
                      key: const Key('transportSearch_submit'),
                      onPressed: _isLoading ? null : _search,
                      child: const Text('Szukaj transportu'),
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
                  label: 'Transport loading',
                  child: ListView.builder(
                    itemCount: 3,
                    itemBuilder: (context, index) => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: LinearProgressIndicator(),
                    ),
                  ),
                );
              }

              if (_hasSearched && _journeys.isEmpty) {
                return const Center(child: Text('Nie znaleziono połączeń transportu publicznego'));
              }

              if (_journeys.isEmpty) {
                return const Center(child: Text('Wyszukaj, aby zobaczyć połączenia transportu publicznego'));
              }

              return ListView.builder(
                itemCount: _journeys.length,
                itemBuilder: (context, index) => _buildJourneyCard(_journeys[index]),
              );
            },
          ),
        ),
      ],
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
  final bool canContribute;

  const AttractionsSearchView({
    super.key,
    required this.eventId,
    required this.initialCity,
    this.canContribute = true,
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
                    trailing: widget.canContribute
                        ? IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors.green, size: 30),
                            onPressed: () => _addToItinerary(attraction),
                            tooltip: 'Dodaj do planu wycieczki',
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class ChatView extends StatefulWidget {
  final String eventId;

  const ChatView({super.key, required this.eventId});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _sending = false;
  String? _errorMessage;
  Timer? _pollTimer;

  String get _baseUrl => kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    // Lekki polling, aby na bieżąco pobierać nowe wiadomości od innych uczestników.
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchMessages(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, String> _headers(AuthState authState, {bool json = false}) {
    return {
      if (json) 'Content-Type': 'application/json',
      if (authState.token != null) 'Authorization': 'Token ${authState.token}',
    };
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    final authState = Provider.of<AuthState>(context, listen: false);
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/events/${widget.eventId}/messages/'),
        headers: _headers(authState),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final newMessages = decoded is List ? decoded : <dynamic>[];
        final hadMore = newMessages.length != _messages.length;
        setState(() {
          _messages = newMessages;
          _isLoading = false;
          _errorMessage = null;
        });
        if (hadMore) _scrollToBottom();
      } else if (!silent) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Nie udało się pobrać wiadomości (${response.statusCode}).';
        });
      }
    } catch (e) {
      if (!mounted || silent) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Błąd połączenia: $e';
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final authState = Provider.of<AuthState>(context, listen: false);
    setState(() => _sending = true);

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/events/${widget.eventId}/messages/'),
        headers: _headers(authState, json: true),
        body: jsonEncode({'content': text}),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        _controller.clear();
        await _fetchMessages(silent: true);
        _scrollToBottom();
      } else {
        String msg = 'Nie udało się wysłać wiadomości (${response.statusCode}).';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['detail'] is String) msg = decoded['detail'] as String;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd połączenia: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    try {
      return DateFormat('HH:mm').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return '';
    }
  }

  Widget _buildBubble(Map<String, dynamic> message, bool isMine) {
    final username = (message['sender_username'] as String?) ?? 'Użytkownik';
    final content = (message['content'] as String?) ?? '';
    final time = _formatTime(message['created_at'] as String?);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isMine ? Colors.blueAccent : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Text(
                username,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
              ),
            Text(
              content,
              style: TextStyle(color: isMine ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 2),
            Text(
              time,
              style: TextStyle(
                fontSize: 10,
                color: isMine ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = Provider.of<AuthState>(context, listen: false);
    final currentUserId = authState.currentUser?.id;

    return Column(
      children: [
        Expanded(
          child: Builder(
            builder: (context) {
              if (_isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (_errorMessage != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 8),
                        ElevatedButton(onPressed: _fetchMessages, child: const Text('Ponów')),
                      ],
                    ),
                  ),
                );
              }
              if (_messages.isEmpty) {
                return const Center(child: Text('Brak wiadomości. Napisz pierwszą!'));
              }
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = (_messages[index] as Map).cast<String, dynamic>();
                  final senderId = (message['sender_id'] as num?)?.toInt();
                  final isMine = currentUserId != null && senderId == currentUserId;
                  return _buildBubble(message, isMine);
                },
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_sending,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: 'Napisz wiadomość...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : _sendMessage,
                icon: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                tooltip: 'Wyślij',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PollsView extends StatefulWidget {
  final String eventId;
  final String destinationCity;
  final bool canContribute;

  const PollsView({super.key, required this.eventId, this.destinationCity = '', this.canContribute = true});

  @override
  State<PollsView> createState() => _PollsViewState();
}

class _PollsViewState extends State<PollsView> {
  List<dynamic> _polls = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _busy = false;

  String get _baseUrl => kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';

  Map<String, String> _headers({bool json = false}) {
    final authState = Provider.of<AuthState>(context, listen: false);
    return {
      if (authState.token != null) 'Authorization': 'Token ${authState.token}',
      if (json) 'Content-Type': 'application/json',
    };
  }

  @override
  void initState() {
    super.initState();
    _fetchPolls();
  }

  Future<void> _fetchPolls({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/events/${widget.eventId}/polls/'),
        headers: _headers(),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _polls = jsonDecode(utf8.decode(response.bodyBytes));
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Błąd pobierania ankiet: ${response.statusCode}';
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

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _vote(String pollId, int optionId) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/events/${widget.eventId}/polls/$pollId/vote/'),
        headers: _headers(json: true),
        body: jsonEncode({'option_id': optionId}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        await _fetchPolls(silent: true);
      } else {
        _snack('Nie udało się oddać głosu: ${response.statusCode}');
      }
    } catch (e) {
      _snack('Błąd połączenia: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addOption(String pollId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await _postOption(pollId, {'text': trimmed});
  }

  Future<void> _addApiOption(String pollId, Map<String, dynamic> option) async {
    await _postOption(pollId, option);
  }

  Future<void> _postOption(String pollId, Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/events/${widget.eventId}/polls/$pollId/options/'),
        headers: _headers(json: true),
        body: jsonEncode(body),
      );
      if (!mounted) return;
      if (response.statusCode == 201) {
        await _fetchPolls(silent: true);
      } else {
        _snack('Nie udało się dodać propozycji: ${response.statusCode}');
      }
    } catch (e) {
      _snack('Błąd połączenia: $e');
    }
  }

  Future<void> _pickApiOption(String pollId) async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ApiOptionPicker(destinationCity: widget.destinationCity),
    );
    if (selected != null) {
      await _addApiOption(pollId, selected);
    }
  }

  Future<void> _closePoll(String pollId) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/v1/events/${widget.eventId}/polls/$pollId/close/'),
        headers: _headers(json: true),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        await _fetchPolls(silent: true);
      } else if (response.statusCode == 403) {
        _snack('Tylko autor ankiety lub organizator może ją zamknąć.');
      } else {
        _snack('Nie udało się zamknąć ankiety: ${response.statusCode}');
      }
    } catch (e) {
      _snack('Błąd połączenia: $e');
    }
  }

  Future<void> _addOptionToPlan(Map<String, dynamic> option, String pollQuestion) async {
    final optionText = option['text'] ?? '';
    final pollItemType = (option['item_type'] as String?) ?? 'OTHER';
    // Plan obsługuje typy ATTRACTION / HOTEL / FLIGHT / OTHER; transport -> OTHER.
    final planItemType = pollItemType == 'TRANSPORT' ? 'OTHER' : pollItemType;
    final optionDescription = (option['description'] as String?)?.trim() ?? '';
    final description = optionDescription.isNotEmpty
        ? '$optionDescription\n(z ankiety: $pollQuestion)'
        : 'Z ankiety: $pollQuestion';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/events/${widget.eventId}/itinerary/'),
        headers: _headers(json: true),
        body: jsonEncode({
          'title': optionText,
          'item_type': planItemType,
          'description': description,
          if (option['location_lat'] != null) 'location_lat': option['location_lat'],
          if (option['location_lon'] != null) 'location_lon': option['location_lon'],
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 201 || response.statusCode == 200) {
        _snack('Dodano "$optionText" do planu.');
      } else {
        _snack('Nie udało się dodać do planu: ${response.statusCode}');
      }
    } catch (e) {
      _snack('Błąd połączenia: $e');
    }
  }

  Future<void> _showCreatePollDialog() async {
    final questionController = TextEditingController();
    final optionControllers = <TextEditingController>[
      TextEditingController(),
      TextEditingController(),
    ];
    final apiOptions = <Map<String, dynamic>>[];

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Nowa ankieta'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: questionController,
                      decoration: const InputDecoration(
                        labelText: 'Pytanie',
                        hintText: 'np. Czym dojeżdżamy?',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Propozycje (opcjonalnie):', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    ...optionControllers.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: entry.value,
                                decoration: InputDecoration(labelText: 'Opcja ${entry.key + 1}'),
                              ),
                            ),
                            if (optionControllers.length > 1)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => setDialogState(() => optionControllers.removeAt(entry.key)),
                              ),
                          ],
                        ),
                      );
                    }),
                    ...apiOptions.asMap().entries.map((entry) {
                      final opt = entry.value;
                      return Card(
                        color: const Color(0xFFF1F8E9),
                        margin: const EdgeInsets.only(top: 8),
                        child: ListTile(
                          dense: true,
                          leading: Icon(_iconForType(opt['item_type'] as String?), size: 20),
                          title: Text(opt['text'] ?? ''),
                          subtitle: (opt['description'] as String?)?.isNotEmpty == true
                              ? Text(opt['description'], maxLines: 2, overflow: TextOverflow.ellipsis)
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => setDialogState(() => apiOptions.removeAt(entry.key)),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Tekst'),
                            onPressed: () => setDialogState(() => optionControllers.add(TextEditingController())),
                          ),
                        ),
                        Expanded(
                          child: TextButton.icon(
                            icon: const Icon(Icons.travel_explore),
                            label: const Text('Z API'),
                            onPressed: () async {
                              final selected = await showModalBottomSheet<Map<String, dynamic>>(
                                context: context,
                                isScrollControlled: true,
                                builder: (_) => ApiOptionPicker(destinationCity: widget.destinationCity),
                              );
                              if (selected != null) {
                                setDialogState(() => apiOptions.add(selected));
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
                ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Utwórz')),
              ],
            );
          },
        );
      },
    );

    if (created == true) {
      final question = questionController.text.trim();
      if (question.isEmpty) {
        _snack('Pytanie ankiety jest wymagane.');
      } else {
        final options = <dynamic>[
          ...optionControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty),
          ...apiOptions,
        ];
        await _createPoll(question, options);
      }
    }
    questionController.dispose();
    for (final c in optionControllers) {
      c.dispose();
    }
  }

  IconData _iconForType(String? itemType) {
    switch (itemType) {
      case 'TRANSPORT':
        return Icons.directions_transit;
      case 'HOTEL':
        return Icons.hotel;
      case 'ATTRACTION':
        return Icons.local_activity;
      default:
        return Icons.label_outline;
    }
  }

  Future<void> _createPoll(String question, List<dynamic> options) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/events/${widget.eventId}/polls/'),
        headers: _headers(json: true),
        body: jsonEncode({'question': question, 'options': options}),
      );
      if (!mounted) return;
      if (response.statusCode == 201) {
        await _fetchPolls(silent: true);
        _snack('Utworzono ankietę.');
      } else {
        _snack('Nie udało się utworzyć ankiety: ${response.statusCode}');
      }
    } catch (e) {
      _snack('Błąd połączenia: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null) {
      body = Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)));
    } else if (_polls.isEmpty) {
      body = RefreshIndicator(
        onRefresh: _fetchPolls,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 100),
            Center(child: Text('Brak ankiet. Utwórz pierwszą!')),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _fetchPolls,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: _polls.length,
          itemBuilder: (context, index) => _buildPollCard(_polls[index] as Map<String, dynamic>),
        ),
      );
    }

    return Scaffold(
      body: body,
      floatingActionButton: widget.canContribute
          ? FloatingActionButton.extended(
              onPressed: _showCreatePollDialog,
              icon: const Icon(Icons.add),
              label: const Text('Ankieta'),
            )
          : null,
    );
  }

  Widget _buildPollCard(Map<String, dynamic> poll) {
    final authState = Provider.of<AuthState>(context, listen: false);
    final currentUserId = authState.currentUser?.id;
    final pollId = poll['id'].toString();
    final isClosed = poll['is_closed'] == true;
    final totalVotes = (poll['total_votes'] as num?)?.toInt() ?? 0;
    final myVote = (poll['my_vote'] as num?)?.toInt();
    final options = (poll['options'] as List?) ?? const [];
    final createdById = (poll['created_by_id'] as num?)?.toInt();
    final canClose = !isClosed && currentUserId != null && createdById == currentUserId;
    final optionController = TextEditingController();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    poll['question'] ?? '',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                if (isClosed)
                  const Chip(
                    label: Text('Zamknięta'),
                    backgroundColor: Color(0xFFE0E0E0),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            Text(
              'Autor: ${poll['created_by_username'] ?? '—'} • Głosów: $totalVotes',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            ...options.map((o) => _buildOptionTile(
                  poll: poll,
                  pollId: pollId,
                  option: o as Map<String, dynamic>,
                  totalVotes: totalVotes,
                  myVote: myVote,
                  isClosed: isClosed,
                )),
            if (!isClosed) ...[
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: optionController,
                      decoration: const InputDecoration(
                        hintText: 'Dodaj własną propozycję...',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (v) => _addOption(pollId, v),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blueAccent),
                    tooltip: 'Dodaj propozycję',
                    onPressed: () => _addOption(pollId, optionController.text),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.travel_explore, size: 18),
                  label: const Text('Dodaj z wyszukiwarki (transport / nocleg / atrakcje)'),
                  onPressed: () => _pickApiOption(pollId),
                ),
              ),
            ],
            if (canClose)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('Zamknij ankietę'),
                  onPressed: () => _closePoll(pollId),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required Map<String, dynamic> poll,
    required String pollId,
    required Map<String, dynamic> option,
    required int totalVotes,
    required int? myVote,
    required bool isClosed,
  }) {
    final optionId = (option['id'] as num).toInt();
    final voteCount = (option['vote_count'] as num?)?.toInt() ?? 0;
    final isMyVote = myVote == optionId;
    final fraction = totalVotes > 0 ? voteCount / totalVotes : 0.0;
    final percent = (fraction * 100).round();
    final itemType = option['item_type'] as String?;
    final description = (option['description'] as String?)?.trim() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: isClosed || _busy ? null : () => _vote(pollId, optionId),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isMyVote ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          size: 18,
                          color: isMyVote ? Colors.blueAccent : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        if (itemType != null && itemType != 'OTHER') ...[
                          Icon(_iconForType(itemType), size: 16, color: Colors.blueGrey),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            option['text'] ?? '',
                            style: TextStyle(fontWeight: isMyVote ? FontWeight.bold : FontWeight.normal),
                          ),
                        ),
                        Text('$voteCount ($percent%)', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                    if (description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 24, top: 2),
                        child: Text(
                          description,
                          style: const TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.canContribute)
            IconButton(
              icon: const Icon(Icons.playlist_add, color: Colors.green),
              tooltip: 'Dodaj do planu',
              onPressed: () => _addOptionToPlan(option, poll['question'] ?? ''),
            ),
        ],
      ),
    );
  }
}

enum _ApiOptionCategory { transport, hotel, attraction }

class ApiOptionPicker extends StatefulWidget {
  final String destinationCity;

  const ApiOptionPicker({super.key, this.destinationCity = ''});

  @override
  State<ApiOptionPicker> createState() => _ApiOptionPickerState();
}

class _ApiOptionPickerState extends State<ApiOptionPicker> {
  _ApiOptionCategory _category = _ApiOptionCategory.transport;

  late final TextEditingController _fromController;
  late final TextEditingController _toController;
  late final TextEditingController _cityController;

  late final TransportApi _transportApi;
  late final HotelApi _hotelApi;

  bool _isLoading = false;
  String? _error;
  List<Journey> _journeys = const [];
  List<Hotel> _hotels = const [];
  List<dynamic> _attractions = const [];

  String get _baseUrl => kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';

  @override
  void initState() {
    super.initState();
    _fromController = TextEditingController();
    _toController = TextEditingController(text: widget.destinationCity);
    _cityController = TextEditingController(text: widget.destinationCity);
    _transportApi = TransportApi(baseUrl: ApiEnvironment.baseUrl);
    _hotelApi = HotelApi(baseUrl: ApiEnvironment.baseUrl);
  }

  @override
  void dispose() {
    _transportApi.cancelOngoing();
    _hotelApi.cancelOngoing();
    _fromController.dispose();
    _toController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  void _resetResults() {
    _journeys = const [];
    _hotels = const [];
    _attractions = const [];
  }

  Future<void> _search() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _resetResults();
    });
    try {
      switch (_category) {
        case _ApiOptionCategory.transport:
          final from = _fromController.text.trim();
          final to = _toController.text.trim();
          if (from.isEmpty || to.isEmpty) {
            throw 'Podaj miejsce początkowe i docelowe.';
          }
          final result = await _transportApi.searchTransport(from: from, to: to);
          if (!mounted) return;
          setState(() => _journeys = result.results);
          break;
        case _ApiOptionCategory.hotel:
          final city = _cityController.text.trim();
          if (city.isEmpty) throw 'Podaj miasto.';
          final result = await _hotelApi.searchHotels(q: city);
          if (!mounted) return;
          setState(() => _hotels = result.results);
          break;
        case _ApiOptionCategory.attraction:
          final city = _cityController.text.trim();
          if (city.isEmpty) throw 'Podaj miasto.';
          await _searchAttractions(city);
          break;
      }
      if (mounted && _journeys.isEmpty && _hotels.isEmpty && _attractions.isEmpty && _error == null) {
        setState(() => _error = 'Brak wyników.');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchAttractions(String city) async {
    final authState = Provider.of<AuthState>(context, listen: false);
    final response = await http.get(
      Uri.parse('$_baseUrl/api/v1/attractions/search/?city=${Uri.encodeComponent(city)}'),
      headers: {
        if (authState.token != null) 'Authorization': 'Token ${authState.token}',
      },
    );
    if (!mounted) return;
    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      List<dynamic> results = [];
      if (decoded is List) {
        results = decoded;
      } else if (decoded is Map) {
        results = decoded['data'] ?? decoded['features'] ?? decoded['results'] ?? [];
      }
      setState(() => _attractions = results);
    } else {
      setState(() => _error = 'Błąd wyszukiwania: ${response.statusCode}');
    }
  }

  void _selectTransport(Journey j) {
    final from = j.fromName ?? _fromController.text.trim();
    final to = j.toName ?? _toController.text.trim();
    final parts = <String>[];
    if (j.durationText != null) parts.add(j.durationText!);
    parts.add(j.transfers == 0 ? 'bez przesiadek' : 'przesiadki: ${j.transfers}');
    if (j.departure != null && j.arrival != null) parts.add('${j.departure}–${j.arrival}');
    Navigator.pop(context, <String, dynamic>{
      'text': '$from → $to',
      'item_type': 'TRANSPORT',
      'description': parts.join(' • '),
    });
  }

  void _selectHotel(Hotel h) {
    final parts = <String>[];
    if (h.accommodationType != null && h.accommodationType!.isNotEmpty) parts.add(h.accommodationType!);
    if (h.review?.rating != null) parts.add('ocena ${h.review!.rating}');
    final price = h.priceRanges?.minimum ?? (h.rates.isNotEmpty ? h.rates.first.perNight : null);
    if (price != null) parts.add('od ${price.round()} za noc');
    Navigator.pop(context, <String, dynamic>{
      'text': h.name,
      'item_type': 'HOTEL',
      'description': parts.join(' • '),
    });
  }

  void _selectAttraction(dynamic a) {
    final name = a['name'] ?? a['title'] ?? 'Atrakcja';
    final lat = a['lat'] != null ? (a['lat'] as num).toDouble() : null;
    final rawLon = a['lon'] ?? a['lng'];
    final lon = rawLon != null ? (rawLon as num).toDouble() : null;
    final option = <String, dynamic>{
      'text': name,
      'item_type': 'ATTRACTION',
      'description': 'Atrakcja w ${_cityController.text.trim()}',
    };
    if (lat != null) option['location_lat'] = lat;
    if (lon != null) option['location_lon'] = lon;
    Navigator.pop(context, option);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Dodaj opcję z wyszukiwarki', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Transport'),
                    avatar: const Icon(Icons.directions_transit, size: 18),
                    selected: _category == _ApiOptionCategory.transport,
                    onSelected: (_) => setState(() {
                      _category = _ApiOptionCategory.transport;
                      _error = null;
                      _resetResults();
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Nocleg'),
                    avatar: const Icon(Icons.hotel, size: 18),
                    selected: _category == _ApiOptionCategory.hotel,
                    onSelected: (_) => setState(() {
                      _category = _ApiOptionCategory.hotel;
                      _error = null;
                      _resetResults();
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Atrakcje'),
                    avatar: const Icon(Icons.local_activity, size: 18),
                    selected: _category == _ApiOptionCategory.attraction,
                    onSelected: (_) => setState(() {
                      _category = _ApiOptionCategory.attraction;
                      _error = null;
                      _resetResults();
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_category == _ApiOptionCategory.transport) ...[
                TextField(
                  controller: _fromController,
                  decoration: const InputDecoration(labelText: 'Skąd', isDense: true, border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _toController,
                  decoration: const InputDecoration(labelText: 'Dokąd', isDense: true, border: OutlineInputBorder()),
                ),
              ] else
                TextField(
                  controller: _cityController,
                  decoration: const InputDecoration(labelText: 'Miasto', isDense: true, border: OutlineInputBorder()),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _search,
                  icon: const Icon(Icons.search),
                  label: const Text('Szukaj'),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildResults(scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResults(ScrollController scrollController) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: const TextStyle(color: Colors.red)));

    switch (_category) {
      case _ApiOptionCategory.transport:
        return ListView.builder(
          controller: scrollController,
          itemCount: _journeys.length,
          itemBuilder: (context, i) {
            final j = _journeys[i];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.directions_transit, color: Colors.blueAccent),
                title: Text('${j.fromName ?? _fromController.text} → ${j.toName ?? _toController.text}'),
                subtitle: Text([
                  if (j.durationText != null) j.durationText!,
                  j.transfers == 0 ? 'bez przesiadek' : 'przesiadki: ${j.transfers}',
                ].join(' • ')),
                trailing: const Icon(Icons.add_circle, color: Colors.green),
                onTap: () => _selectTransport(j),
              ),
            );
          },
        );
      case _ApiOptionCategory.hotel:
        return ListView.builder(
          controller: scrollController,
          itemCount: _hotels.length,
          itemBuilder: (context, i) {
            final h = _hotels[i];
            final price = h.priceRanges?.minimum ?? (h.rates.isNotEmpty ? h.rates.first.perNight : null);
            return Card(
              child: ListTile(
                leading: const Icon(Icons.hotel, color: Colors.blueAccent),
                title: Text(h.name),
                subtitle: Text([
                  if (h.review?.rating != null) 'ocena ${h.review!.rating}',
                  if (price != null) 'od ${price.round()} za noc',
                ].join(' • ')),
                trailing: const Icon(Icons.add_circle, color: Colors.green),
                onTap: () => _selectHotel(h),
              ),
            );
          },
        );
      case _ApiOptionCategory.attraction:
        return ListView.builder(
          controller: scrollController,
          itemCount: _attractions.length,
          itemBuilder: (context, i) {
            final a = _attractions[i];
            return Card(
              child: ListTile(
                leading: const Icon(Icons.local_activity, color: Colors.blueAccent),
                title: Text(a['name'] ?? a['title'] ?? 'Atrakcja'),
                trailing: const Icon(Icons.add_circle, color: Colors.green),
                onTap: () => _selectAttraction(a),
              ),
            );
          },
        );
    }
  }
}
