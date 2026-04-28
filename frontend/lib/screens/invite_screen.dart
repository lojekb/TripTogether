import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:trip_together/services/auth_state.dart';

// Zmienna globalna przechowująca token zaproszenia do przetworzenia po zalogowaniu
String? pendingInviteToken;

class InviteScreen extends StatefulWidget {
  final String token;
  final bool autoJoin;

  const InviteScreen({super.key, required this.token, this.autoJoin = false});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  bool _isLoading = true;
  bool _isJoining = false;
  Map<String, dynamic>? _eventData;
  String? _inviterName;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchPreview().then((_) {
      if (widget.autoJoin && mounted) {
        _joinEvent();
      }
    });
  }

  // Dynamiczny adres API w zależności od platformy
  String get _baseUrl {
    return kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';
  }

  Future<void> _fetchPreview() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/invitations/${widget.token}/'),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // DEBUG: Sprawdźmy, co faktycznie dostajemy z API
        print('Otrzymane dane z API: $data');
        print('Typ dla klucza "inviter": ${data['inviter'].runtimeType}');

        setState(() {
          _eventData = data['event'];
          _inviterName = data['inviter'];
          _isLoading = false;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _errorMessage = 'Zaproszenie nie istnieje lub jest nieprawidłowe.';
          _isLoading = false;
        });
      } else if (response.statusCode == 410) {
        setState(() {
          _errorMessage = 'To zaproszenie już wygasło.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Wystąpił błąd podczas pobierania zaproszenia.';
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

  Future<void> _joinEvent() async {
    final authState = Provider.of<AuthState>(context, listen: false);
    
    // Weryfikacja czy użytkownik jest zalogowany
    if (authState.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Musisz się zalogować, aby dołączyć do wydarzenia.')),
      );
      pendingInviteToken = widget.token;
      Navigator.of(context).pushNamed('/login').then((_) {
        if (mounted && Provider.of<AuthState>(context, listen: false).token != null) {
          pendingInviteToken = null;
          _joinEvent();
        } else {
          pendingInviteToken = null; // Wyczyść, jeśli użytkownik zrezygnował z logowania
        }
      });
      return;
    }

    setState(() {
      _isJoining = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/invitations/${widget.token}/join/'),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Token ${authState.token}",
        },
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pomyślnie dołączono do wydarzenia!')),
        );
        // Powrót do ekranu głównego po dołączeniu
        Navigator.of(context).pushReplacementNamed('/');
      } else if (response.statusCode == 409) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Jesteś już uczestnikiem tego wydarzenia.')),
        );
      } else if (response.statusCode == 410) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('To zaproszenie już wygasło.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd: ${response.body}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd połączenia: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zaproszenie'),
      ),
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
          child: Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 16)),
        ),
      );
    }

    if (_eventData == null) {
      return const Center(child: Text('Brak danych wydarzenia.'));
    }

    final title = _eventData!['title'] ?? 'Nieznane wydarzenie';
    final city = _eventData!['destination_city'] ?? '';
    final country = _eventData!['destination_country'] ?? '';
    final startDate = _eventData!['start_date'] ?? '';
    final endDate = _eventData!['end_date'] ?? '';
    final description = _eventData!['description'] ?? '';
    final inviterName = _inviterName ?? 'Kogoś';

    final String location = [city, country].where((e) => e.isNotEmpty).join(', ');
    String dates = '';
    if (startDate.isNotEmpty && endDate.isNotEmpty) {
      dates = '$startDate  do  $endDate';
    } else if (startDate.isNotEmpty) {
      dates = startDate;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.card_giftcard, size: 64, color: Colors.blue),
            const SizedBox(height: 24),
            Text(
              'Zostałeś zaproszony!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              'Użytkownik $inviterName zaprasza Cię na wydarzenie:',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (location.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Text(location, style: const TextStyle(fontSize: 16)),
                ],
              ),
            const SizedBox(height: 8),
            if (dates.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Text(dates, style: const TextStyle(fontSize: 16)),
                ],
              ),
            const SizedBox(height: 16),
            if (description.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 32),
            _isJoining
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _joinEvent,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    ),
                    child: const Text('Dołącz do wydarzenia', style: TextStyle(fontSize: 16)),
                  ),
          ],
        ),
      ),
    );
  }
}