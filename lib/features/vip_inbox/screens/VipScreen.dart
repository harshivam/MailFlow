import 'package:flutter/material.dart';
import 'package:mail_merge/features/vip_inbox/services/contact_service.dart';
import 'package:mail_merge/features/email/widgets/email_item.dart';
import 'package:mail_merge/features/email/services/email_service.dart';
import 'package:mail_merge/user/authentication/google_sign_in.dart';
import 'package:mail_merge/features/vip_inbox/screens/contacts_screen.dart';
import 'package:mail_merge/features/vip_inbox/screens/add_contact_screen.dart';
import 'package:mail_merge/features/email/widgets/email_shimmer.dart';

class VipScreen extends StatefulWidget {
  const VipScreen({super.key});

  @override
  State<VipScreen> createState() => _VipScreenState();
}

class _VipScreenState extends State<VipScreen> {
  List<Map<String, dynamic>> _vipEmails = [];
  bool _isLoading = true; // Initial loading state
  bool _isRefreshing = false; // Separate state for refresh operations
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    _loadVipEmails();
  }

  Future<void> _loadVipEmails({bool refresh = false}) async {
    if (refresh) {
      setState(() => _isRefreshing = true);
    } else if (!_isLoading) {
      setState(() => _isLoading = true);
    }

    try {
      // Get access token
      _accessToken = await getGoogleAccessToken();
      if (_accessToken == null) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
        return;
      }

      // Get VIP contacts
      final vipContacts = await ContactService.getVipContacts();

      if (vipContacts.isEmpty) {
        setState(() {
          _vipEmails = [];
          _isLoading = false;
          _isRefreshing = false;
        });
        return;
      }

      // Build query from VIP contacts
      final vipEmails = vipContacts.map((c) => c.email.toLowerCase()).toList();
      final fromQuery = 'from:(${vipEmails.join(' OR ')})';

      // Fetch emails with the query
      final emailService = EmailService(_accessToken!);
      final vipFilteredEmails = await emailService.fetchEmailsWithQuery(
        fromQuery,
        maxResults: 20,
      );

      if (mounted) {
        setState(() {
          _vipEmails = vipFilteredEmails;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      print('Error loading VIP emails: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only show shimmer for initial loading when there's no data
    if (_isLoading && _vipEmails.isEmpty) {
      return const EmailShimmerList(itemCount: 8);
    }

    // Empty state with "Add VIP Contact" button
    if (_vipEmails.isEmpty) {
      return Stack(
        children: [
          RefreshIndicator(
            onRefresh: () => _loadVipEmails(refresh: true),
            child: ListView(
              physics:
                  const AlwaysScrollableScrollPhysics(), // Enable pull-to-refresh even when empty
              children: [
                SizedBox(height: MediaQuery.of(context).size.height / 4),
                const Icon(Icons.star, size: 80, color: Colors.amber),
                const SizedBox(height: 16),
                const Text(
                  'No VIP emails',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add contacts to your VIP list to see their emails here',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ContactsScreen(),
                        ),
                      ).then((_) => _loadVipEmails());
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text('Manage VIP Contacts'),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Pull down to refresh',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          // Floating action button
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddContactScreen(),
                  ),
                );

                if (result == true) {
                  _loadVipEmails();
                }
              },
              tooltip: 'Add VIP Contact',
              child: const Icon(Icons.person_add),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _loadVipEmails(refresh: true),
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
        ),
        // Floating action button
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddContactScreen(),
                ),
              );

              if (result == true) {
                _loadVipEmails();
              }
            },
            tooltip: 'Add VIP Contact',
            child: const Icon(Icons.person_add),
          ),
        ),
      ],
    );
  }
}
