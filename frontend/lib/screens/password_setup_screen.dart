import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/backup_provider.dart';

class PasswordSetupScreen extends StatefulWidget {
  final String configId;
  final Function(String) onPasswordSet;

  const PasswordSetupScreen({
    Key? key,
    required this.configId,
    required this.onPasswordSet,
  }) : super(key: key);

  @override
  State<PasswordSetupScreen> createState() => _PasswordSetupScreenState();
}

class _PasswordSetupScreenState extends State<PasswordSetupScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showPassword = false;
  bool _isValidating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Encryption Password'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create a Strong Password',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your password will be converted to a 256-bit key using PBKDF2 and used to encrypt your files with AES-256-GCM.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _passwordController,
              obscureText: !_showPassword,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_passwordController.text.isNotEmpty)
              Consumer<BackupProvider>(
                builder: (context, backupProvider, _) {
                  final strength = backupProvider.passwordStrength;
                  if (strength == null) return const SizedBox.shrink();

                  final score = strength['score'] as int? ?? 0;
                  final feedback = (strength['feedback'] as List?)?.cast<String>() ?? [];
                  final isValid = strength['isValid'] as bool? ?? false;

                  Color scoreColor = Colors.red;
                  String scoreText = 'Weak';
                  if (score >= 4) {
                    scoreColor = Colors.green;
                    scoreText = 'Strong';
                  } else if (score >= 3) {
                    scoreColor = Colors.orange;
                    scoreText = 'Fair';
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: score / 5,
                              minHeight: 8,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            scoreText,
                            style: TextStyle(
                              color: scoreColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (feedback.isNotEmpty)
                        ...feedback.map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.info, size: 16, color: Colors.orange),
                              const SizedBox(width: 8),
                              Expanded(child: Text(f, style: const TextStyle(fontSize: 12))),
                            ],
                          ),
                        )),
                      if (isValid)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: const [
                              Icon(Icons.check_circle, size: 16, color: Colors.green),
                              SizedBox(width: 8),
                              Text('Password meets security requirements', style: TextStyle(fontSize: 12, color: Colors.green)),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isValidating || _passwordController.text.isEmpty
                    ? null
                    : () async {
                        if (_passwordController.text != _confirmPasswordController.text) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Passwords do not match')),
                          );
                          return;
                        }

                        setState(() => _isValidating = true);

                        final authProvider = context.read<AuthProvider>();
                        final backupProvider = context.read<BackupProvider>();

                        final isValid = await backupProvider.validatePassword(
                          _passwordController.text,
                          authProvider.token!,
                        );

                        setState(() => _isValidating = false);

                        if (isValid && mounted) {
                          widget.onPasswordSet(_passwordController.text);
                          Navigator.pop(context);
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Password does not meet security requirements')),
                          );
                        }
                      },
                child: _isValidating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Set Password'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
