import 'package:flutter/material.dart';
import 'api_service.dart';

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

  @override
  void initState() {
    super.initState();

    print('USER DATA: ${widget.user}');

    _emailVerified = widget.user['email_verified_at'] != null;
    _phoneVerified = widget.user['phone_verified_at'] != null;

    print('EMAIL VERIFIED: $_emailVerified');
    print('PHONE VERIFIED: $_phoneVerified');
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

      // Demo mode: the API returns the OTP instead of sending it.
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Demo OTP Generated'),
          content: Text(
            'Your ${isEmail ? 'email' : 'phone'} OTP is:\n\n'
                '${result['otp']}\n\n'
                'In this demo, the OTP is displayed instead of being '
                'sent through email or SMS.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
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

      if (!mounted) return;

      setState(() {
        if (isEmail) {
          _emailVerified = true;
          _emailOtpController.clear();
        } else {
          _phoneVerified = true;
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
              'Welcome, ${widget.user['full_name']}!',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            _buildVerificationSection(
              title: 'Email Verification',
              destination: widget.user['email'] ?? '',
              verified: _emailVerified,
              sending: _sendingEmail,
              verifying: _verifyingEmail,
              controller: _emailOtpController,
              onSend: () => _sendOtp('email'),
              onVerify: () => _verifyOtp('email'),
            ),

            _buildVerificationSection(
              title: 'Phone Verification',
              destination: widget.user['phone'] ?? '',
              verified: _phoneVerified,
              sending: _sendingPhone,
              verifying: _verifyingPhone,
              controller: _phoneOtpController,
              onSend: () => _sendOtp('phone'),
              onVerify: () => _verifyOtp('phone'),
            ),
          ],
        ),
      ),
    );
  }
}