import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trip_together/services/auth_state.dart';

class LoginPage extends StatefulWidget {
  final String baseUrl;
  final VoidCallback? onLoggedIn;

  const LoginPage({super.key, required this.baseUrl, this.onLoggedIn});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Form validity is determined by Form validators on submit.

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthState>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email', errorText: auth.fieldErrors['email']?.first),
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email is required';
                  final re = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
                  if (!re.hasMatch(v)) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Password', errorText: auth.fieldErrors['password']?.first),
                obscureText: true,
                validator: (v) => (v == null || v.isEmpty) ? 'Password required' : null,
              ),
              const SizedBox(height: 20),
              if (auth.nonFieldErrors.isNotEmpty) ...auth.nonFieldErrors.map((e) => Text(e, style: const TextStyle(color: Colors.red))),
              ElevatedButton(
                onPressed: auth.loading
                    ? null
                    : () async {
                        FocusScope.of(context).unfocus();
                        final valid = _formKey.currentState?.validate() ?? true;
                        if (!valid) return;
                        final ok = await auth.login(email: _emailController.text.trim(), password: _passwordController.text);
                        if (ok) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logged in')));
                          if (widget.onLoggedIn != null) widget.onLoggedIn!();
                          else Navigator.of(context).pushReplacementNamed('/');
                        }
                      },
                child: auth.loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
