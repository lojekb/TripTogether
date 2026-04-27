import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trip_together/api_service.dart';
import 'package:trip_together/pages/registration_page.dart';
import 'package:trip_together/pages/login_page.dart';
import 'package:trip_together/services/auth_state.dart';
import 'package:trip_together/services/auth_service.dart';
import 'screens/create_event_screen.dart'; // Importujemy nowy ekran formularza

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
    } else {
      setState(() => _events = []);
    }
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
              return ListTile(
                leading: const Icon(Icons.flight_takeoff),
                title: Text(_events[index]['title']),
                subtitle: Text('ID: ${_events[index]['id']}'),
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