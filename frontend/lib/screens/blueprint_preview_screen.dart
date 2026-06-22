import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trip_together/api_service.dart';
import 'package:trip_together/services/auth_state.dart';

String? pendingBlueprintToken;
Map<String, String>? pendingBlueprintEdits;

class BlueprintPreviewScreen extends StatefulWidget {
  final String token;
  final bool autoCopy;
  final ApiService? apiService;

  const BlueprintPreviewScreen({
    required this.token,
    this.autoCopy = false,
    this.apiService,
    super.key,
  });

  @override
  State<BlueprintPreviewScreen> createState() => _BlueprintPreviewScreenState();
}

class _BlueprintPreviewScreenState extends State<BlueprintPreviewScreen> {
  late final ApiService _api = widget.apiService ?? ApiService();

  bool _isLoading = true;
  bool _isCopying = false;
  String? _errorMessage;
  Map<String, dynamic>? _blueprint;
  String? _author;

  final _titleController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _fetchBlueprint().then((_) {
      if (widget.autoCopy && mounted && _errorMessage == null) {
        final edits = pendingBlueprintEdits;
        pendingBlueprintEdits = null;
        if (edits != null) {
          _titleController.text = edits['title'] ?? _titleController.text;
          _startDate = DateTime.tryParse(edits['start_date'] ?? '') ?? _startDate;
          _endDate = DateTime.tryParse(edits['end_date'] ?? '') ?? _endDate;
        }
        _copyBlueprint();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-$month-$day';
  }

  Future<void> _pickStartDate() async {
    final initial = _startDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      if (_endDate != null && _endDate!.isBefore(picked)) {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final first = _startDate ?? DateTime(2000);
    final initial = _endDate ?? _startDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _endDate = picked);
  }

  Future<void> _fetchBlueprint() async {
    final data = await _api.getBlueprint(widget.token);
    if (!mounted) return;
    if (data == null || data['blueprint'] == null) {
      setState(() {
        _errorMessage = 'Ten plan nie istnieje lub link jest nieprawidłowy.';
        _isLoading = false;
      });
      return;
    }
    final blueprint = data['blueprint'] as Map<String, dynamic>;
    setState(() {
      _blueprint = blueprint;
      _author = data['created_by'] as String?;
      _titleController.text = blueprint['title']?.toString() ?? '';
      _startDate = DateTime.tryParse(blueprint['start_date']?.toString() ?? '');
      _endDate = DateTime.tryParse(blueprint['end_date']?.toString() ?? '');
      _isLoading = false;
    });
  }

  Future<void> _copyBlueprint() async {
    final authState = Provider.of<AuthState>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    if (authState.token == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Musisz się zalogować, aby skopiować plan.')),
      );
      pendingBlueprintToken = widget.token;
      pendingBlueprintEdits = {
        'title': _titleController.text,
        'start_date': _formatDate(_startDate),
        'end_date': _formatDate(_endDate),
      };
      Navigator.of(context).pushNamed('/login');
      return;
    }

    setState(() => _isCopying = true);
    final result = await _api.copyBlueprint(
      widget.token,
      authToken: authState.token!,
      title: _titleController.text,
      startDate: _formatDate(_startDate),
      endDate: _formatDate(_endDate),
    );
    if (!mounted) return;
    setState(() => _isCopying = false);

    if (result == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nie udało się utworzyć wydarzenia. Sprawdź daty.')),
      );
      return;
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Utworzono nowe wydarzenie na podstawie planu!')),
    );
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kopiuj plan podróży')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      );
    }

    final blueprint = _blueprint!;
    final city = blueprint['destination_city']?.toString() ?? '';
    final country = blueprint['destination_country']?.toString() ?? '';
    final location = [city, country].where((e) => e.isNotEmpty).join(', ');
    final itinerary = (blueprint['itinerary'] as List<dynamic>? ?? []);
    final author = _author ?? 'ktoś';

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.copy_all, size: 56, color: Colors.blue),
        const SizedBox(height: 16),
        Text(
          'Plan podróży udostępniony przez $author',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 4),
        if (location.isNotEmpty)
          Text(
            location,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        const SizedBox(height: 24),
        Text('Dostosuj swoje wydarzenie', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(labelText: 'Nazwa', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _DateField(
                key: const Key('startDateField'),
                label: 'Data od',
                value: _formatDate(_startDate),
                onTap: _pickStartDate,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _DateField(
                key: const Key('endDateField'),
                label: 'Data do',
                value: _formatDate(_endDate),
                onTap: _pickEndDate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Skopiowany plan (${itinerary.length})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (itinerary.isEmpty)
          const Text('Ten plan nie zawiera jeszcze żadnych pozycji.')
        else
          ...itinerary.map((item) {
            final map = item as Map<String, dynamic>;
            return ListTile(
              dense: true,
              leading: const Icon(Icons.place_outlined),
              title: Text(map['title']?.toString() ?? ''),
              subtitle: (map['description']?.toString().isNotEmpty ?? false)
                  ? Text(map['description'].toString())
                  : null,
            );
          }),
        const SizedBox(height: 24),
        _isCopying
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton(
                onPressed: _copyBlueprint,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Utwórz moje wydarzenie', style: TextStyle(fontSize: 16)),
              ),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(value.isEmpty ? 'Wybierz datę' : value),
      ),
    );
  }
}
