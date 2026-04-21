import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trip_together/services/auth_service.dart';

class RegistrationModel extends ChangeNotifier {
  final AuthService authService;

  bool loading = false;
  Map<String, List<String>> fieldErrors = {};
  List<String> nonFieldErrors = [];

  RegistrationModel({required this.authService});

  Future<bool> register({
    required String email,
    required String username,
    required String password,
    required String passwordConfirm,
  }) async {
    loading = true;
    fieldErrors = {};
    nonFieldErrors = [];
    notifyListeners();

    try {
      await authService.register(
        email: email,
        username: username,
        password: password,
        passwordConfirm: passwordConfirm,
      );
      loading = false;
      notifyListeners();
      return true;
    } on ValidationException catch (ve) {
      fieldErrors = ve.errors;
    } catch (e) {
      nonFieldErrors = [e.toString()];
    }

    loading = false;
    notifyListeners();
    return false;
  }
}

class RegistrationPage extends StatefulWidget {
  final String baseUrl;
  final VoidCallback? onRegistered;
  final RegistrationModel? model;

  const RegistrationPage({super.key, required this.baseUrl, this.onRegistered, this.model});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() => setState(() {}));
    _usernameController.addListener(() => setState(() {}));
    _passwordController.addListener(() => setState(() {}));
    _passwordConfirmController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final providerWidget = widget.model != null
        ? ChangeNotifierProvider<RegistrationModel>.value(
            value: widget.model!,
            child: _buildScaffold(),
          )
        : ChangeNotifierProvider(
            create: (_) => RegistrationModel(
              authService: AuthService(baseUrl: widget.baseUrl),
            ),
            child: _buildScaffold(),
          );

    return providerWidget;
  }

  Widget _buildScaffold() {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: Consumer<RegistrationModel>(
        builder: (context, model, _) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      errorText: _firstErrorFor(model, 'email'),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Email is required';
                      final re = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
                      if (!re.hasMatch(v)) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      errorText: _firstErrorFor(model, 'username'),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.isEmpty) ? 'Username is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      errorText: _firstErrorFor(model, 'password'),
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      if (v.length < 8) return 'Password must be at least 8 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordConfirmController,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      errorText: _firstErrorFor(model, 'password_confirm'),
                    ),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please confirm password';
                      if (v != _passwordController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  if (model.nonFieldErrors.isNotEmpty)
                    ...model.nonFieldErrors.map((e) => Text(e, style: const TextStyle(color: Colors.red))),
                  ElevatedButton(
                    onPressed: model.loading
                        ? null
                        : () async {
                            FocusScope.of(context).unfocus();
                            final formValid = _formKey.currentState?.validate() ?? true;
                            if (!formValid) {
                              // client-side validation failed; don't call server
                              return;
                            }

                            final ok = await model.register(
                              email: _emailController.text.trim(),
                              username: _usernameController.text.trim(),
                              password: _passwordController.text,
                              passwordConfirm: _passwordConfirmController.text,
                            );

                            if (ok) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Registration successful')),
                              );
                              if (widget.onRegistered != null) {
                                widget.onRegistered!();
                              } else {
                                // default behavior: navigate to '/login'
                                Navigator.of(context).pushReplacementNamed('/login');
                              }
                            } else {
                              if (!mounted) return;
                              if (model.fieldErrors.isNotEmpty) {
                                // show field errors inline; already bound to fields via errorText
                                // show top-level snackbar for visibility
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Please fix the errors in the form')),
                                );
                              }
                            }
                          },
                    child: model.loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Register'),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String? _firstErrorFor(RegistrationModel model, String field) {
    final v = model.fieldErrors[field];
    if (v != null && v.isNotEmpty) return v.first;
    return null;
  }

  bool _isFormValid() {
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirm = _passwordConfirmController.text;
    final emailRegex = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
    final emailOk = email.isNotEmpty && emailRegex.hasMatch(email);
    final usernameOk = username.isNotEmpty;
    final passwordOk = password.length >= 8;
    final passwordsMatch = password == confirm && confirm.isNotEmpty;
    return emailOk && usernameOk && passwordOk && passwordsMatch;
  }
}
