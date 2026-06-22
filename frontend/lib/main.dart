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
import 'screens/blueprint_preview_screen.dart';
import 'screens/event_details_screen.dart';
import 'screens/notifications_screen.dart';

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
          '/register': (ctx) =>
              const RegistrationPage(baseUrl: 'http://localhost:8000'),
          '/login': (ctx) => const LoginPage(baseUrl: 'http://localhost:8000'),
        },
        onGenerateRoute: (settings) {
          final uri = Uri.parse(settings.name ?? '/');
          if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'invite') {
            final autoJoin = uri.queryParameters['autoJoin'] == 'true';
            return MaterialPageRoute(
              builder: (_) =>
                  InviteScreen(token: uri.pathSegments[1], autoJoin: autoJoin),
            );
          }
          if (uri.pathSegments.length >= 2 &&
              uri.pathSegments[0] == 'blueprint') {
            final autoCopy = uri.queryParameters['autoCopy'] == 'true';
            return MaterialPageRoute(
              builder: (_) => BlueprintPreviewScreen(
                token: uri.pathSegments[1],
                autoCopy: autoCopy,
              ),
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
  int _unreadNotifications = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthState>(context);
    if (auth.currentUser != null) {
      _refreshHomeData(auth.token);

      if (pendingInviteToken != null) {
        final token = pendingInviteToken;
        pendingInviteToken = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushNamed('/invite/$token?autoJoin=true');
        });
      }

      if (pendingBlueprintToken != null) {
        final token = pendingBlueprintToken;
        pendingBlueprintToken = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushNamed('/blueprint/$token?autoCopy=true');
        });
      }
    } else {
      setState(() {
        _events = [];
        _unreadNotifications = 0;
      });
    }
  }

  Future<void> _refreshHomeData(String? token) async {
    await Future.wait([_fetchEvents(token), _fetchUnreadNotifications(token)]);
  }

  Future<void> _shareInvitation(BuildContext context, String eventId) async {
    final auth = Provider.of<AuthState>(context, listen: false);
    if (auth.token == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final result = await _apiService.generateInvitation(
      eventId,
      authToken: auth.token!,
    );
    if (!mounted) return;
    if (result == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Error generating link.')),
      );
      return;
    }
    final inviteUrl = '${Uri.base.origin}/#/invite/${result['token']}';
    await Clipboard.setData(ClipboardData(text: inviteUrl));
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Link copied!')));
  }

  Future<void> _shareBlueprint(BuildContext context, String eventId) async {
    final auth = Provider.of<AuthState>(context, listen: false);
    if (auth.token == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final result = await _apiService.generateBlueprint(
      eventId,
      authToken: auth.token!,
    );
    if (!mounted) return;
    if (result == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Error generating link.')),
      );
      return;
    }
    final blueprintUrl = '${Uri.base.origin}/#/blueprint/${result['token']}';
    await Clipboard.setData(ClipboardData(text: blueprintUrl));
    if (!mounted) return;
    messenger.showSnackBar(
      const SnackBar(content: Text('Link do skopiowania planu skopiowany!')),
    );
  }

  Future<void> _fetchEvents(String? token) async {
    final events = await _apiService.getEvents(token: token);
    if (mounted) {
      setState(() => _events = events);
    }
  }

  Future<void> _fetchUnreadNotifications(String? token) async {
    if (token == null) return;
    final notifications = await _apiService.getNotifications(authToken: token);
    if (!mounted) return;
    setState(() {
      _unreadNotifications = notifications
          .where((item) => item['is_read'] != true)
          .length;
    });
  }

  Widget _buildNotificationsButton(String token) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_none),
          color: Colors.black87,
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            );
            if (mounted) {
              await _fetchUnreadNotifications(token);
            }
          },
        ),
        if (_unreadNotifications > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                _unreadNotifications > 99 ? '99+' : '$_unreadNotifications',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TripTogether Events'),
        actions: [
          Consumer<AuthState>(
            builder: (context, auth, _) {
              if (auth.currentUser == null) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/login'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black87,
                      ),
                      child: const Text('Login'),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/register'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black87,
                      ),
                      child: const Text('Register'),
                    ),
                  ],
                );
              }

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildNotificationsButton(auth.token!),
                  IconButton(
                    tooltip: 'Logout',
                    icon: const Icon(Icons.logout),
                    color: Colors.black87,
                    onPressed: () {
                      auth.logout();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Logged out')),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<AuthState>(
        builder: (context, auth, _) {
          if (auth.currentUser == null) {
            return const Center(
              child: Text(
                'Log in to see your trips.',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (_events.isEmpty) {
            return const Center(
              child: Text('No events found. Create the first one!'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _events.length,
            itemBuilder: (context, index) {
              final event = _events[index];
              return ListTile(
                leading: const Icon(Icons.flight_takeoff),
                title: Text(event['title']),
                subtitle: Text(
                  '${event['destination_city']}, ${event['destination_country']}',
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventDetailsScreen(event: event),
                    ),
                  );
                },
                trailing: PopupMenuButton<String>(
                  icon: const Icon(Icons.share),
                  tooltip: 'Udostępnij',
                  onSelected: (value) {
                    final eventId = event['id'].toString();
                    if (value == 'invite') {
                      _shareInvitation(context, eventId);
                    } else if (value == 'blueprint') {
                      _shareBlueprint(context, eventId);
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'invite',
                      child: ListTile(
                        leading: Icon(Icons.person_add),
                        title: Text('Zaproś do wydarzenia'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'blueprint',
                      child: ListTile(
                        leading: Icon(Icons.copy_all),
                        title: Text('Udostępnij plan do skopiowania'),
                      ),
                    ),
                  ],
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
