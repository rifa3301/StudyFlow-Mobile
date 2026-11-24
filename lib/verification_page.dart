import 'package:flutter/material.dart';

import 'api_service.dart';
import 'dashboard_page.dart';

class VerificationPage extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const VerificationPage({
    super.key,
    required this.token,
    required this.user,
  });

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final _emailOtpController = TextEditingController();
  final _phoneOtpController = TextEditingController();

  bool _sendingEmail = false;
  bool _sendingPhone = false;
  bool _verifyingEmail = false;
  bool _verifyingPhone = false;

  late bool _emailVerified;
  late bool _phoneVerified;

  late Map<String, dynamic> _currentUser;

  @override
  void initState() {
    super.initState();

    _currentUser = Map<String, dynamic>.from(widget.user);

    _emailVerified = _currentUser['email_verified_at'] != null;
    _phoneVerified = _currentUser['phone_verified_at'] != null;
  }

  Future<void> _sendOtp(String channel) async {
    final isEmail = channel == 'email';

    setState(() {
      if (isEmail) {
        _sendingEmail = true;
      } else {
        _sendingPhone = true;
      }
    });

    try {
      final result = await ApiService.sendOtp(
        token: widget.token,
        channel: channel,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message'] ??
                'Verification request accepted. Please check your inbox.',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          if (isEmail) {
            _sendingEmail = false;
          } else {
            _sendingPhone = false;
          }
        });
      }
    }
  }

  Future<void> _verifyOtp(String channel) async {
    final isEmail = channel == 'email';

    final otp = isEmail
        ? _emailOtpController.text.trim()
        : _phoneOtpController.text.trim();

    if (otp.length != 6 || int.tryParse(otp) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid six-digit OTP.'),
        ),
      );
      return;
    }

    setState(() {
      if (isEmail) {
        _verifyingEmail = true;
      } else {
        _verifyingPhone = true;
      }
    });

    try {
      await ApiService.verifyOtp(
        token: widget.token,
        channel: channel,
        otp: otp,
      );

      final updatedUser = await ApiService.getCurrentUser(widget.token);

      if (!mounted) return;

      setState(() {
        _currentUser = Map<String, dynamic>.from(updatedUser);

        _emailVerified = _currentUser['email_verified_at'] != null;
        _phoneVerified = _currentUser['phone_verified_at'] != null;

        if (isEmail) {
          _emailOtpController.clear();
        } else {
          _phoneOtpController.clear();
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${isEmail ? 'Email' : 'Phone'} verified successfully!',
          ),
          backgroundColor: Colors.green,
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
          if (isEmail) {
            _verifyingEmail = false;
          } else {
            _verifyingPhone = false;
          }
        });
      }
    }
  }

  void _continueAfterVerification() {
    if (!_emailVerified || !_phoneVerified) {
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DashboardPage(
          token: widget.token,
          user: _currentUser,
        ),
      ),
    );
  }

  Widget _buildVerificationSection({
    required String title,
    required String destination,
    required bool verified,
    required bool sending,
    required bool verifying,
    required TextEditingController controller,
    required VoidCallback onSend,
    required VoidCallback onVerify,
  }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(destination),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  verified ? Icons.verified : Icons.error_outline,
                  color: verified ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  verified ? 'Verified' : 'Not verified',
                  style: TextStyle(
                    color: verified ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (!verified) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: sending ? null : onSend,
                child: sending
                    ? const CircularProgressIndicator()
                    : const Text('Send OTP'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Enter six-digit OTP',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: verifying ? null : onVerify,
                child: verifying
                    ? const CircularProgressIndicator()
                    : const Text('Verify OTP'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailOtpController.dispose();
    _phoneOtpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bothVerified = _emailVerified && _phoneVerified;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Verification'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.verified_user,
              size: 65,
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            const Text(
              'Verify Your Contact Details',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Welcome, ${_currentUser['full_name']}!',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            _buildVerificationSection(
              title: 'Email Verification',
              destination: _currentUser['email']?.toString() ?? '',
              verified: _emailVerified,
              sending: _sendingEmail,
              verifying: _verifyingEmail,
              controller: _emailOtpController,
              onSend: () => _sendOtp('email'),
              onVerify: () => _verifyOtp('email'),
            ),

            _buildVerificationSection(
              title: 'Phone Verification',
              destination: _currentUser['phone']?.toString() ?? '',
              verified: _phoneVerified,
              sending: _sendingPhone,
              verifying: _verifyingPhone,
              controller: _phoneOtpController,
              onSend: () => _sendOtp('phone'),
              onVerify: () => _verifyOtp('phone'),
            ),

            if (bothVerified) ...[
              const SizedBox(height: 8),
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 45,
              ),
              const SizedBox(height: 8),
              const Text(
                'All contact details verified!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _continueAfterVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}