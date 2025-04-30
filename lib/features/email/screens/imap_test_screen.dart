import 'package:flutter/material.dart';
import 'package:mail_merge/features/email/services/providers/imap_email_service.dart';
import 'package:mail_merge/user/models/email_account.dart';
import 'package:mail_merge/features/email/widgets/email_item.dart';

class ImapTestScreen extends StatefulWidget {
  const ImapTestScreen({super.key});

  @override
  State<ImapTestScreen> createState() => _ImapTestScreenState();
}

class _ImapTestScreenState extends State<ImapTestScreen> {
  bool _isLoading = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _emails = [];
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  Future<void> _testImapConnection() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _emails = [];
    });
    
    try {
      // Create test account (would be replaced with real authentication)
      final testAccount = EmailAccount(
        email: _emailController.text,
        displayName: 'Test User',
        provider: AccountProvider.outlook, // Assume Outlook for testing
        accessToken: _passwordController.text, // Using password as token for simplicity
        refreshToken: '',
        tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
      );
      
      // Create IMAP service
      final imapService = ImapEmailService(testAccount);
      
      // Fetch emails
      final emails = await imapService.fetchEmails(maxResults: 10);
      
      setState(() {
        _emails = emails;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IMAP Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _testImapConnection,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Test IMAP Connection'),
            ),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            if (_emails.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Emails fetched successfully:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _emails.length,
                  itemBuilder: (context, index) {
                    final email = _emails[index];
                    return EmailItem(
                      name: email["name"] ?? "Unknown",
                      subject: email["message"] ?? "",
                      time: email["time"] ?? "",
                      snippet: email["snippet"] ?? "",
                      avatar: email["avatar"] ?? "https://via.placeholder.com/150",
                      emailData: email,
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}