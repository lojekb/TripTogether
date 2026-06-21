import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:trip_together/services/auth_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;

  String get _baseUrl {
    return kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';
  }

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final authState = Provider.of<AuthState>(context, listen: false);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/notifications/'),
        headers: {
          if (authState.token != null)
            'Authorization': 'Token ${authState.token}',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _notifications = jsonDecode(response.body) as List<dynamic>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Błąd pobierania powiadomień: ${response.statusCode}';
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

  Future<void> _markAsRead(String notificationId) async {
    final authState = Provider.of<AuthState>(context, listen: false);

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/v1/notifications/$notificationId/read/'),
        headers: {
          if (authState.token != null)
            'Authorization': 'Token ${authState.token}',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        await _fetchNotifications();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Błąd połączenia: $e')));
    }
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'EVENT_UPDATED':
        return Icons.event_note;
      case 'POLL_CREATED':
        return Icons.how_to_vote;
      case 'POLL_OPTION_ADDED':
        return Icons.add_circle_outline;
      case 'POLL_CLOSED':
        return Icons.lock_outline;
      default:
        return Icons.notifications_none;
    }
  }

  Color _colorForType(String? type) {
    switch (type) {
      case 'EVENT_UPDATED':
        return Colors.blueAccent;
      case 'POLL_CREATED':
        return Colors.green;
      case 'POLL_OPTION_ADDED':
        return Colors.orange;
      case 'POLL_CLOSED':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  String _formatDate(String? value) {
    if (value == null) return '';
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return '';
    return DateFormat('dd.MM HH:mm').format(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Powiadomienia'),
        actions: [
          IconButton(
            tooltip: 'Odśwież',
            onPressed: _fetchNotifications,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : _notifications.isEmpty
          ? RefreshIndicator(
              onRefresh: _fetchNotifications,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Brak powiadomień.')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchNotifications,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final notification =
                      _notifications[index] as Map<String, dynamic>;
                  final isRead = notification['is_read'] == true;
                  final id = notification['id'].toString();
                  final createdAt = _formatDate(
                    notification['created_at'] as String?,
                  );
                  final type = notification['notification_type'] as String?;

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    color: isRead ? null : const Color(0xFFF3F8FF),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _colorForType(
                          type,
                        ).withValues(alpha: 0.15),
                        child: Icon(
                          _iconForType(type),
                          color: _colorForType(type),
                        ),
                      ),
                      title: Text(
                        notification['title'] ?? '',
                        style: TextStyle(
                          fontWeight: isRead
                              ? FontWeight.w500
                              : FontWeight.bold,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(notification['message'] ?? ''),
                          if ((notification['event_title'] as String?)
                                  ?.isNotEmpty ==
                              true)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Wydarzenie: ${notification['event_title']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          if ((notification['poll_question'] as String?)
                                  ?.isNotEmpty ==
                              true)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Ankieta: ${notification['poll_question']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          if ((notification['actor_username'] as String?)
                                  ?.isNotEmpty ==
                              true)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Autor: ${notification['actor_username']}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ),
                          if (createdAt.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                createdAt,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black45,
                                ),
                              ),
                            ),
                        ],
                      ),
                      trailing: isRead
                          ? const Icon(Icons.done, color: Colors.green)
                          : IconButton(
                              tooltip: 'Oznacz jako przeczytane',
                              onPressed: () => _markAsRead(id),
                              icon: const Icon(Icons.mark_email_read_outlined),
                            ),
                      onTap: isRead ? null : () => _markAsRead(id),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
