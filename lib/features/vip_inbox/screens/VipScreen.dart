import 'package:flutter/material.dart';
import 'package:mail_merge/features/vip_inbox/services/contact_service.dart';
import 'package:mail_merge/features/email/widgets/email_item.dart';
import 'package:mail_merge/features/email/services/email_service.dart';
import 'package:mail_merge/user/authentication/google_sign_in.dart';
import 'package:mail_merge/features/vip_inbox/screens/contacts_screen.dart';

class VipScreen extends StatefulWidget {
  const VipScreen({super.key});

  @override
  State<VipScreen> createState() => _VipScreenState();
}

class _VipScreenState extends State<VipScreen> {
  List<Map<String, dynamic>> _vipEmails = [];
  bool _isLoading = false;
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    _loadVipEmails();
  }

  Future<void> _loadVipEmails() async {
    setState(() => _isLoading = true);

    try {
      // Get access token
      _accessToken = await getGoogleAccessToken();
      if (_accessToken == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get VIP contacts
      final vipContacts = await ContactService.getVipContacts();

      if (vipContacts.isEmpty) {
        setState(() {
          _vipEmails = [];
          _isLoading = false;
        });
        return;
      }

      // Create a query parameter to filter emails server-side
      // This uses Gmail's search syntax to filter by sender
      final vipEmails = vipContacts.map((c) => c.email.toLowerCase()).toList();

      // Build a Gmail search query like: from:(email1@example.com OR email2@example.com)
      final fromQuery = 'from:(${vipEmails.join(' OR ')})';

      // Fetch emails with the query
      final emailService = EmailService(_accessToken!);
      final vipFilteredEmails = await emailService.fetchEmailsWithQuery(
        fromQuery,
        maxResults: 20,
      );

      setState(() {
        _vipEmails = vipFilteredEmails;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading VIP emails: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_vipEmails.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.star, size: 80, color: Colors.amber),
            const SizedBox(height: 16),
            const Text(
              'No VIP emails',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add contacts to your VIP list to see their emails here',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ContactsScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Manage VIP Contacts'),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _loadVipEmails,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVipEmails,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _vipEmails.length,
        itemBuilder: (context, index) {
          final email = _vipEmails[index];
          return EmailItem(
            name: email["name"] ?? "Unknown",
            subject: email["message"] ?? "",
            time: email["time"] ?? "",
            snippet: email["snippet"] ?? "",
            avatar:
                email["avatar"] ??
                "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png",
          );
        },
      ),
    );
  }
}
