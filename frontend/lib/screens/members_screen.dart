import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
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

  const MembersScreen({
    super.key,
    required this.eventId,
    required this.eventTitle,
    required this.canManageRoles,
    this.currentUserRole,
  });

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  List<dynamic> _members = [];
  bool _isLoading = true;
  String? _errorMessage;

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
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await http.get(
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

  List<String> _assignableRoles() {
    // Owner may also grant the ADMIN role; an admin can only set MEMBER/EDITOR.
    return _isOwner ? ['MEMBER', 'EDITOR', 'ADMIN'] : ['MEMBER', 'EDITOR'];
  }

  Future<void> _changeRole(dynamic member, String newRole) async {
    final userId = member['user_id'];
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/v1/events/${widget.eventId}/members/$userId/role/'),
        headers: _headers(json: true),
        body: jsonEncode({'role': newRole}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        _snack('Zmieniono rolę użytkownika ${member['username']} na ${_roleLabels[newRole]}.');
        _fetchMembers();
      } else {
        String msg = 'Błąd zmiany roli: ${response.statusCode}';
        try {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map && decoded['detail'] is String) msg = decoded['detail'];
        } catch (_) {}
        _snack(msg);
      }
    } catch (e) {
      _snack('Błąd połączenia: $e');
    }
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
      appBar: AppBar(title: const Text('Uczestnicy i role')),
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
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _members.length,
        itemBuilder: (context, index) {
          final member = _members[index] as Map<String, dynamic>;
          final role = member['role'] as String? ?? 'MEMBER';
          final isOwnerRow = role == 'OWNER';
          // Admins cannot edit other admins; only the owner can.
          final editable = widget.canManageRoles && !isOwnerRow && !(role == 'ADMIN' && !_isOwner);

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
              trailing: editable
                  ? PopupMenuButton<String>(
                      onSelected: (newRole) => _changeRole(member, newRole),
                      itemBuilder: (context) => _assignableRoles()
                          .where((r) => r != role)
                          .map((r) => PopupMenuItem<String>(
                                value: r,
                                child: Text('Ustaw: ${_roleLabels[r]}'),
                              ))
                          .toList(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _roleChip(role),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    )
                  : _roleChip(role),
            ),
          );
        },
      ),
    );
  }
}
