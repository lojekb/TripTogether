import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:trip_together/services/auth_state.dart';

const Map<String, String> _roleLabels = {
  'OWNER': 'Właściciel',
  'ADMIN': 'Administrator',
  'EDITOR': 'Uprawniony',
  'MEMBER': 'Członek',
};

class MembersScreen extends StatefulWidget {
  final String eventId;
  final String eventTitle;
  final bool canManageRoles;
  final String? currentUserRole;
  final Map<String, dynamic>? event;
  final http.Client? client;

  const MembersScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.canManageRoles,
    this.currentUserRole,
    this.event,
    this.client,
  });

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  List<dynamic> _members = [];
  bool _isLoading = true;
  String? _errorMessage;
  late Map<String, dynamic> _event;

  late final http.Client _client = widget.client ?? http.Client();

  String get _baseUrl => kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';

  bool get _isOwner => widget.currentUserRole == 'OWNER';

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
    _event = Map<String, dynamic>.from(widget.event ?? {'title': widget.eventTitle});
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/api/v1/events/${widget.eventId}/members/'),
        headers: _headers(),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _members = jsonDecode(utf8.decode(response.bodyBytes));
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Błąd pobierania uczestników: ${response.statusCode}';
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

  String _detailOr(dynamic body, String fallback) {
    try {
      final decoded = jsonDecode(utf8.decode(body));
      if (decoded is Map && decoded['detail'] is String) return decoded['detail'];
    } catch (_) {}
    return fallback;
  }

  List<String> _assignableRoles() {
    // Owner may also grant the ADMIN role; an admin can only set MEMBER/EDITOR.
    return _isOwner ? ['MEMBER', 'EDITOR', 'ADMIN'] : ['MEMBER', 'EDITOR'];
  }

  Future<void> _changeRole(dynamic member, String newRole) async {
    final userId = member['user_id'];
    try {
      final response = await _client.put(
        Uri.parse('$_baseUrl/api/v1/events/${widget.eventId}/members/$userId/role/'),
        headers: _headers(json: true),
        body: jsonEncode({'role': newRole}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        _snack('Zmieniono rolę użytkownika ${member['username']} na ${_roleLabels[newRole]}.');
        _fetchMembers();
      } else {
        _snack(_detailOr(response.bodyBytes, 'Błąd zmiany roli: ${response.statusCode}'));
      }
    } catch (e) {
      _snack('Błąd połączenia: $e');
    }
  }

  Future<void> _confirmRemoveMember(dynamic member) async {
    final username = member['username'] ?? 'tego uczestnika';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Usunąć uczestnika?'),
        content: Text('Czy na pewno chcesz usunąć $username z wydarzenia?'),
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
      await _removeMember(member);
    }
  }

  Future<void> _removeMember(dynamic member) async {
    final userId = member['user_id'];
    try {
      final response = await _client.delete(
        Uri.parse('$_baseUrl/api/v1/events/${widget.eventId}/members/$userId/'),
        headers: _headers(),
      );
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        _snack('Usunięto uczestnika ${member['username']}.');
        _fetchMembers();
      } else {
        _snack(_detailOr(response.bodyBytes, 'Błąd usuwania: ${response.statusCode}'));
      }
    } catch (e) {
      _snack('Błąd połączenia: $e');
    }
  }

  Future<void> _editDetails() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EditEventDialog(event: _event),
    );
    if (result == null) return;
    try {
      final response = await _client.put(
        Uri.parse('$_baseUrl/api/v1/events/${widget.eventId}/'),
        headers: _headers(json: true),
        body: jsonEncode(result),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final updated = jsonDecode(utf8.decode(response.bodyBytes));
        if (updated is Map<String, dynamic>) {
          setState(() => _event = {..._event, ...updated});
        }
        _snack('Zapisano szczegóły wydarzenia.');
      } else {
        _snack(_detailOr(response.bodyBytes, 'Błąd zapisu: ${response.statusCode}'));
      }
    } catch (e) {
      _snack('Błąd połączenia: $e');
    }
  }

  bool _canRemove(String role) {
    // The owner row is never removable, and only the owner may remove an admin.
    // A manager can therefore never remove their own row, so no self check is needed.
    if (!widget.canManageRoles) return false;
    if (role == 'OWNER') return false;
    if (role == 'ADMIN' && !_isOwner) return false;
    return true;
  }

  Widget _roleChip(String role) {
    Color color;
    switch (role) {
      case 'OWNER':
        color = Colors.deepPurple;
        break;
      case 'ADMIN':
        color = Colors.indigo;
        break;
      case 'EDITOR':
        color = Colors.teal;
        break;
      default:
        color = Colors.blueGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _roleLabels[role] ?? role,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.canManageRoles ? 'Zarządzanie wydarzeniem' : 'Uczestnicy'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)));
    }
    return RefreshIndicator(
      onRefresh: _fetchMembers,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (widget.canManageRoles) _buildDetailsCard(),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Lista uczestników', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ..._members.map(_buildMemberCard),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    final title = _event['title']?.toString() ?? widget.eventTitle;
    final city = _event['destination_city']?.toString() ?? '';
    final country = _event['destination_country']?.toString() ?? '';
    final location = [city, country].where((e) => e.isNotEmpty).join(', ');
    final start = _event['start_date']?.toString() ?? '';
    final end = _event['end_date']?.toString() ?? '';
    final dates = [start, end].where((e) => e.isNotEmpty).join(' – ');

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Szczegóły wydarzenia', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (location.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.place, size: 16, color: Colors.redAccent),
                const SizedBox(width: 6),
                Text(location),
              ]),
            ],
            if (dates.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.blueAccent),
                const SizedBox(width: 6),
                Text(dates),
              ]),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                key: const Key('editEventDetailsButton'),
                icon: const Icon(Icons.edit),
                label: const Text('Edytuj szczegóły'),
                onPressed: _editDetails,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(dynamic raw) {
    final member = raw as Map<String, dynamic>;
    final role = member['role'] as String? ?? 'MEMBER';
    final isOwnerRow = role == 'OWNER';
    final editableRole = widget.canManageRoles && !isOwnerRow && !(role == 'ADMIN' && !_isOwner);
    final canRemove = _canRemove(role);

    final roleControl = editableRole
        ? PopupMenuButton<String>(
            onSelected: (newRole) => _changeRole(member, newRole),
            itemBuilder: (context) => _assignableRoles()
                .where((r) => r != role)
                .map((r) => PopupMenuItem<String>(value: r, child: Text('Ustaw: ${_roleLabels[r]}')))
                .toList(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [_roleChip(role), const Icon(Icons.arrow_drop_down)],
            ),
          )
        : _roleChip(role);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            (member['username'] as String?)?.isNotEmpty == true
                ? (member['username'] as String).substring(0, 1).toUpperCase()
                : '?',
          ),
        ),
        title: Text(member['username'] ?? 'Użytkownik', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(member['email'] ?? ''),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            roleControl,
            if (canRemove)
              IconButton(
                key: Key('removeMember_${member['user_id']}'),
                icon: const Icon(Icons.person_remove, color: Colors.red),
                tooltip: 'Usuń z wydarzenia',
                onPressed: () => _confirmRemoveMember(member),
              ),
          ],
        ),
      ),
    );
  }
}

class _EditEventDialog extends StatefulWidget {
  final Map<String, dynamic> event;

  const _EditEventDialog({required this.event});

  @override
  State<_EditEventDialog> createState() => _EditEventDialogState();
}

class _EditEventDialogState extends State<_EditEventDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _cityController;
  late final TextEditingController _countryController;
  late final TextEditingController _descriptionController;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event['title']?.toString() ?? '');
    _cityController = TextEditingController(text: widget.event['destination_city']?.toString() ?? '');
    _countryController = TextEditingController(text: widget.event['destination_country']?.toString() ?? '');
    _descriptionController = TextEditingController(text: widget.event['description']?.toString() ?? '');
    _startDate = DateTime.tryParse(widget.event['start_date']?.toString() ?? '');
    _endDate = DateTime.tryParse(widget.event['end_date']?.toString() ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _fmt(DateTime? date) => date == null ? '' : DateFormat('yyyy-MM-dd').format(date);

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _startDate = picked;
      if (_endDate != null && _endDate!.isBefore(picked)) _endDate = picked;
    });
  }

  Future<void> _pickEnd() async {
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

  void _save() {
    final payload = <String, dynamic>{
      'title': _titleController.text.trim(),
      'destination_city': _cityController.text.trim(),
      'destination_country': _countryController.text.trim(),
      'description': _descriptionController.text.trim(),
    };
    if (_startDate != null) payload['start_date'] = _fmt(_startDate);
    if (_endDate != null) payload['end_date'] = _fmt(_endDate);
    Navigator.of(context).pop(payload);
  }

  Widget _dateField(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: Text(value.isEmpty ? 'Wybierz datę' : value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edytuj szczegóły'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('editEvent_title'),
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Nazwa', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(labelText: 'Miasto', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _countryController,
              decoration: const InputDecoration(labelText: 'Kraj', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _dateField('Data od', _fmt(_startDate), _pickStart)),
                const SizedBox(width: 12),
                Expanded(child: _dateField('Data do', _fmt(_endDate), _pickEnd)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Opis', border: OutlineInputBorder()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Anuluj')),
        ElevatedButton(onPressed: _save, child: const Text('Zapisz')),
      ],
    );
  }
}
