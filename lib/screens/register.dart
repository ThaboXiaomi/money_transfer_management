import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/config.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _showPassword = false;
  bool _showConfirm = false;

  String _strengthLabel = '';
  double _strengthValue = 0.0;

  void _doRegister() async {
    if (!_formKey.currentState!.validate()) return;
    // server-side pre-check (if backend available)
    if (AppConfig.useBackend) {
      final s = await ApiService.passwordStrength(_pass.text);
      if (s != null && s < AppConfig.passwordMinStrength) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Password too weak (server score ${s.toStringAsFixed(2)})',
            ),
          ),
        );
        return;
      }
    } else {
      if (_strengthValue < AppConfig.passwordMinStrength) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password strength must be Strong or better'),
          ),
        );
        return;
      }
    }
    if (_pass.text != _confirm.text) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }
    setState(() => _loading = true);
    try {
      await ApiService.register(_user.text.trim(), _pass.text.trim(), 'agent');
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Register failed: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _evaluateStrength(_pass.text);
  }

  void _evaluateStrength(String s) {
    double score = 0;
    if (s.length >= 6) score += 0.3;
    if (s.length >= 10) score += 0.2;
    if (RegExp(r'[A-Z]').hasMatch(s)) score += 0.15;
    if (RegExp(r'[0-9]').hasMatch(s)) score += 0.2;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(s)) score += 0.15;
    if (score > 1) score = 1;
    String label;
    if (score > 0.8) {
      label = 'Super Strong';
    } else if (score > 0.6) {
      label = 'Strong';
    } else if (score > 0.4) {
      label = 'Medium';
    } else {
      label = 'Weak';
    }
    setState(() {
      _strengthValue = score;
      _strengthLabel = label;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Register', style: GoogleFonts.lato())),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
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
                      'Create an agent account',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontFamily: GoogleFonts.lato().fontFamily,
                      ),
                    ),
                    const SizedBox(height: 12),
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
                      onChanged: (s) => _evaluateStrength(s),
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
                        if (v == null || v.length < 6)
                          return 'Password min 6 chars';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    // Strength indicator
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: _strengthValue,
                            backgroundColor: Colors.grey.shade300,
                            color: _strengthValue > 0.7
                                ? Colors.green
                                : _strengthValue > 0.4
                                ? Colors.orange
                                : Colors.red,
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_strengthLabel),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Password strength'),
                              content: Text(
                                'Strong passwords are at least 10 characters and include uppercase letters, numbers and special characters. A minimum of 6 characters is required to register. Current configured minimum strength: ${AppConfig.passwordMinStrength.toStringAsFixed(2)} (0..1).',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirm,
                      obscureText: !_showConfirm,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline),
                        labelText: 'Confirm Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => _showConfirm = !_showConfirm),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Confirm password' : null,
                    ),
                    const SizedBox(height: 18),
                    _loading
                        ? const CircularProgressIndicator()
                        : SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _doRegister,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12.0),
                                child: Text('Create Account'),
                              ),
                            ),
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
