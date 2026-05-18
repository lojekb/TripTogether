import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
        body: const TabBarView(
          children: [
            TransportSearchView(),
            AccommodationSearchView(),
            AttractionsSearchView(),
            Center(child: Text('Zaakceptowany plan')),
            Center(child: Text('Czat wydarzenia')),
          ],
        ),
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

class AttractionsSearchView extends StatelessWidget {
  const AttractionsSearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TextField(
            decoration: InputDecoration(
              labelText: 'Miasto/miejsce',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              child: const Text('Szukaj atrakcji'),
            ),
          ),
        ],
      ),
    );
  }
}
