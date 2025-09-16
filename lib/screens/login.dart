import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/config.dart';
import 'register.dart';

class LoginScreen extends StatefulWidget {
  final String nextRole; // 'admin' or 'agent'
  const LoginScreen({super.key, required this.nextRole});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;

  void _doLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ApiService.login(_user.text.trim(), _pass.text.trim());
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.nextRole.toUpperCase()} Login',
          style: GoogleFonts.lato(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Welcome back',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontFamily: GoogleFonts.lato().fontFamily,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to continue as ${widget.nextRole}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _user,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.person),
                        labelText: 'Username',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter username'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _pass,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock),
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter password';
                        if (v.length < 6)
                          return 'Password must be at least 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),
                    _loading
                        ? const CircularProgressIndicator()
                        : Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _doLogin,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 12.0,
                                    ),
                                    child: Text('Sign In'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('New here?'),
                        TextButton(
                          onPressed: () async {
                            final registered = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            );
                            if (registered == true) {
                              // After register we attempt to auto-login
                              try {
                                setState(() => _loading = true);
                                await ApiService.login(
                                  _user.text.trim(),
                                  _pass.text.trim(),
                                );
                                Navigator.pop(context, true);
                              } catch (_) {
                                // ignore, user can login manually
                              } finally {
                                setState(() => _loading = false);
                              }
                            }
                          },
                          child: const Text('Create account'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
