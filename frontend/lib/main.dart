import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:trip_together/api_service.dart';
import 'package:trip_together/pages/registration_page.dart';
import 'package:trip_together/pages/login_page.dart';
import 'package:trip_together/services/auth_state.dart';
import 'package:trip_together/services/auth_service.dart';
import 'screens/create_event_screen.dart';
import 'screens/invite_screen.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService(baseUrl: 'http://localhost:8000');
    return ChangeNotifierProvider(
      create: (_) => AuthState(authService: authService),
      child: MaterialApp(
        theme: ThemeData(primarySwatch: Colors.blue),
        routes: {
          '/': (ctx) => const EventScreen(),
          '/register': (ctx) => const RegistrationPage(baseUrl: 'http://localhost:8000'),
          '/login': (ctx) => const LoginPage(baseUrl: 'http://localhost:8000'),
        },
        onGenerateRoute: (settings) {
          final uri = Uri.parse(settings.name ?? '/');
          if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'invite') {
            final autoJoin = uri.queryParameters['autoJoin'] == 'true';
            return MaterialPageRoute(
              builder: (_) => InviteScreen(token: uri.pathSegments[1], autoJoin: autoJoin),
            );
          }
          return null;
        },
        initialRoute: '/',
      ),
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthState>(context);
    if (auth.currentUser != null) {
      _fetchEvents(auth.token);

      // Automatyczne dołączanie, jeśli użytkownik wrócił na stronę główną po logowaniu
      if (pendingInviteToken != null) {
        final token = pendingInviteToken;
        pendingInviteToken = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushNamed('/invite/$token?autoJoin=true');
        });
      }

    } else {
      setState(() => _events = []);
    }
  }

  Future<void> _shareInvitation(BuildContext context, String eventId) async {
    final auth = Provider.of<AuthState>(context, listen: false);
    if (auth.token == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final result = await _apiService.generateInvitation(eventId, authToken: auth.token!);
    if (!mounted) return;
    if (result == null) {
      messenger.showSnackBar(const SnackBar(content: Text('Błąd generowania linku.')));
      return;
    }
    final inviteUrl = '${Uri.base.origin}/#/invite/${result['token']}';
    await Clipboard.setData(ClipboardData(text: inviteUrl));
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Link skopiowany!')));
  }

  void _fetchEvents(String? token) async {
    final events = await _apiService.getEvents(token: token);
    if (mounted) {
      setState(() => _events = events);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TripTogether Events'),
        actions: [
          Consumer<AuthState>(builder: (context, auth, _) {
            if (auth.currentUser == null) {
              return Row(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,
                    ),
                    onPressed: () => Navigator.of(context).pushNamed('/login'),
                    child: const Text('Login'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,
                    ),
                    onPressed: () => Navigator.of(context).pushNamed('/register'),
                    child: const Text('Register'),
                  ),
                ],
              );
            }

            return ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue,
              ),
              onPressed: () {
                auth.logout();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged out')));
              },
              child: const Text('Logout'),
            );
          }),
        ],
      ),
      body: Consumer<AuthState>(
        builder: (context, auth, _) {
          if (auth.currentUser == null) {
            return const Center(
              child: Text(
                'Zaloguj się, aby zobaczyć swoje wycieczki.',
                textAlign: TextAlign.center,
              ),
            );
          }
          if (_events.isEmpty) {
            return const Center(child: Text('Brak wydarzeń. Utwórz pierwsze!'));
          }
          return ListView.builder(
            itemCount: _events.length,
            itemBuilder: (context, index) {
              final event = _events[index];
              return ListTile(
                leading: const Icon(Icons.flight_takeoff),
                title: Text(event['title']),
                subtitle: Text('${event['destination_city']}, ${event['destination_country']}'),
                trailing: IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Zaproś',
                  onPressed: () => _shareInvitation(context, event['id'].toString()),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final auth = Provider.of<AuthState>(context, listen: false);
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateEventScreen()),
          );
          if (mounted) _fetchEvents(auth.token);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}