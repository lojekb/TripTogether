import 'package:flutter/material.dart';
import 'package:trip_together/api_service.dart';
import 'screens/create_event_screen.dart'; // Importujemy nowy ekran formularza

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: EventScreen(),
    );
  }
}

class EventScreen extends StatefulWidget {
  const EventScreen({super.key});

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _events = [];

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  void _fetchEvents() async {
    var events = await _apiService.getEvents();
    setState(() {
      _events = events;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TripTogether Events')),
      body: _events.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _events.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.flight_takeoff),
                  title: Text(_events[index]['title']),
                  subtitle: Text('ID: ${_events[index]['id']}'),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateEventScreen()),
          );
          // Odświeżenie listy po powrocie z ekranu tworzenia
          _fetchEvents();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}