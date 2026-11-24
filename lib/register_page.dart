import 'dart:async';

import 'package:flutter/material.dart';
import 'api_service.dart';
import 'verification_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  Timer? _debounce;

  // Identifies the latest username-checking request.
  int _usernameCheckVersion = 0;

  bool _checkingUsername = false;
  bool? _usernameAvailable;
  String _usernameMessage = '';
  bool _registering = false;
  bool _obscurePassword = true;

  // ==================================================
  // USERNAME AVAILABILITY CHECK
  // ==================================================

  void _checkUsername(String username) {
    _debounce?.cancel();

    // Invalidate all previous requests.
    final currentVersion = ++_usernameCheckVersion;

    setState(() {
      _checkingUsername = false;
      _usernameAvailable = null;
      _usernameMessage = '';
    });

    final cleanUsername = username.trim();

    // Do not check invalid or incomplete usernames.
    if (cleanUsername.length < 3 ||
        !RegExp(r'^[a-zA-Z0-9_]{3,50}$').hasMatch(cleanUsername)) {
      return;
    }

    // Wait 500 milliseconds after the user stops typing.
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted || currentVersion != _usernameCheckVersion) {
        return;
      }

      setState(() {
        _checkingUsername = true;
      });

      try {
        final available =
        await ApiService.checkUsername(cleanUsername);

        // Ignore outdated responses.
        if (!mounted ||
            currentVersion != _usernameCheckVersion ||
            _usernameController.text.trim() != cleanUsername) {
          return;
        }

        setState(() {
          _usernameAvailable = available;
          _usernameMessage =
          available ? 'Username available' : 'Username already taken';
          _checkingUsername = false;
        });
      } catch (error) {
        // Ignore errors from outdated requests.
        if (!mounted || currentVersion != _usernameCheckVersion) {
          return;
        }

        setState(() {
          _checkingUsername = false;
          _usernameAvailable = null;
          _usernameMessage = 'Could not check username';
        });
      }
    });
  }

  // ==================================================
  // USER REGISTRATION
  // ==================================================

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_usernameAvailable != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose an available username.'),
        ),
      );
      return;
    }

    setState(() {
      _registering = true;
    });

    try {
      final result = await ApiService.register(
        username: _usernameController.text.trim(),
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      final token = result['token'] as String;

      final user = Map<String, dynamic>.from(result['user']);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message']),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => VerificationPage(
            token: token,
            user: user,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _registering = false;
        });
      }
    }
  }

  // ==================================================
  // DISPOSE
  // ==================================================

  @override
  void dispose() {
    // Invalidate any pending username-checking request.
    _usernameCheckVersion++;

    _debounce?.cancel();

    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  // ==================================================
  // BUILD
  // ==================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Join StudyFlow',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Create your account to get started.',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 25),

              // FULL NAME

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) =>
                value == null || value.trim().isEmpty
                    ? 'Enter your full name'
                    : null,
              ),

              const SizedBox(height: 16),

              // USERNAME

              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.alternate_email),
                  suffixIcon: _checkingUsername
                      ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                  )
                      : _usernameAvailable == null
                      ? null
                      : Icon(
                    _usernameAvailable!
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: _usernameAvailable!
                        ? Colors.green
                        : Colors.red,
                  ),
                ),
                onChanged: _checkUsername,
                validator: (value) {
                  if (value == null || value.trim().length < 3) {
                    return 'Username must contain at least 3 characters';
                  }

                  if (!RegExp(r'^[a-zA-Z0-9_]{3,50}$')
                      .hasMatch(value.trim())) {
                    return 'Use only letters, numbers, and underscores';
                  }

                  return null;
                },
              ),

              if (_usernameMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 8),
                  child: Text(
                    _usernameMessage,
                    style: TextStyle(
                      color: _usernameAvailable == true
                          ? Colors.green
                          : _usernameAvailable == false
                          ? Colors.red
                          : Colors.orange,
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              // EMAIL

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (value) =>
                value == null ||
                    !RegExp(r'^[^@]+@[^@]+\.[^@]+$')
                        .hasMatch(value.trim())
                    ? 'Enter a valid email'
                    : null,
              ),

              const SizedBox(height: 16),

              // PHONE NUMBER

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                validator: (value) =>
                value == null || value.trim().isEmpty
                    ? 'Enter your phone number'
                    : null,
              ),

              const SizedBox(height: 16),

              // PASSWORD

              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                validator: (value) =>
                value == null || value.length < 8
                    ? 'Password must contain at least 8 characters'
                    : null,
              ),

              const SizedBox(height: 16),

              // CONFIRM PASSWORD

              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                validator: (value) =>
                value != _passwordController.text
                    ? 'Passwords do not match'
                    : null,
              ),

              const SizedBox(height: 25),

              // REGISTER BUTTON

              ElevatedButton(
                onPressed: _registering ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: _registering
                    ? const CircularProgressIndicator(
                  color: Colors.white,
                )
                    : const Text(
                  'Register',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}