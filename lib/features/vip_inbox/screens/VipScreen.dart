import 'package:flutter/material.dart';
import 'package:mail_merge/features/vip_inbox/services/contact_service.dart';
import 'package:mail_merge/features/email/services/email_service.dart';
import 'package:mail_merge/user/authentication/google_sign_in.dart';
import 'package:mail_merge/features/vip_inbox/screens/contacts_screen.dart';
import 'package:mail_merge/features/vip_inbox/screens/add_contact_screen.dart';
import 'package:mail_merge/features/email/widgets/email_shimmer.dart';
import 'package:mail_merge/features/vip_inbox/models/contact.dart';
import 'package:mail_merge/features/vip_inbox/widgets/contact_folder_item.dart';
import 'package:mail_merge/features/vip_inbox/widgets/contact_email_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class VipScreen extends StatefulWidget {
  const VipScreen({super.key});

  @override
  State<VipScreen> createState() => _VipScreenState();
}

class _VipScreenState extends State<VipScreen>
    with AutomaticKeepAliveClientMixin {
  // Map to store emails grouped by contact
  Map<String, List<Map<String, dynamic>>> _vipEmailsByContact = {};
  List<Contact> _vipContacts = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _accessToken;
  bool _loadingFromCache = false;

  // Currently selected contact (for showing their emails)
  String? _selectedContactEmail;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadCachedVipEmails();
    _loadVipEmails();
    _checkAuthAndClearDataIfNeeded(); // Add this line
  }

  // Add this method to check authentication before building UI

  void _checkAuthAndClearDataIfNeeded() async {
    final user = await getCurrentUser();
    if (user == null && mounted) {
      setState(() {
        // Clear data if user is not authenticated
        _vipEmailsByContact = {};
        _selectedContactEmail = null;
      });
    }
  }

  // Load emails from cache
  Future<void> _loadCachedVipEmails() async {
    try {
      _loadingFromCache = true;
      final prefs = await SharedPreferences.getInstance();

      // Load cached contacts
      final cachedContacts = prefs.getString('cached_vip_contacts');
      if (cachedContacts != null) {
        final List<dynamic> decodedContacts = jsonDecode(cachedContacts);
        _vipContacts =
            decodedContacts
                .map(
                  (item) => Contact.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList();
      }

      // Load cached emails by contact
      final cachedEmails = prefs.getString('cached_vip_emails_by_contact');
      if (cachedEmails != null) {
        final Map<String, dynamic> decodedEmails = jsonDecode(cachedEmails);

        _vipEmailsByContact = {};
        decodedEmails.forEach((key, value) {
          _vipEmailsByContact[key] =
              (value as List)
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList();
        });
      }

      setState(() {
        _loadingFromCache = false;
      });
    } catch (e) {
      print('Error loading cached VIP emails: $e');
      _loadingFromCache = false;
    }
  }

  // Cache emails for faster loading next time
  Future<void> _cacheVipEmails() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Cache contacts
      await prefs.setString(
        'cached_vip_contacts',
        jsonEncode(_vipContacts.map((c) => c.toJson()).toList()),
      );

      // Cache emails grouped by contact
      final Map<String, dynamic> emailsToCache = {};
      _vipEmailsByContact.forEach((key, value) {
        emailsToCache[key] = value;
      });

      await prefs.setString(
        'cached_vip_emails_by_contact',
        jsonEncode(emailsToCache),
      );
    } catch (e) {
      print('Error caching VIP emails: $e');
    }
  }

  Future<void> _loadVipEmails({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _isRefreshing = true;
        _selectedContactEmail = null; // Clear selection on refresh
      });
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
      _vipContacts = vipContacts;

      if (vipContacts.isEmpty) {
        setState(() {
          _vipEmailsByContact = {};
          _isLoading = false;
          _isRefreshing = false;
        });
        _cacheVipEmails(); // Cache empty results
        return;
      }

      // Initialize the email service
      final emailService = EmailService(_accessToken!);

      // Create a map to store emails by contact
      Map<String, List<Map<String, dynamic>>> emailsByContact = {};

      // Fetch emails for each VIP contact in parallel
      final emailFutures = vipContacts.map((contact) async {
        final query = 'from:${contact.email.toLowerCase()}';
        final emails = await emailService.fetchEmailsWithQuery(
          query,
          maxResults: 10, // Limit per contact for better performance
        );
        return MapEntry(contact.email.toLowerCase(), emails);
      });

      // Wait for all email fetches to complete
      final results = await Future.wait(emailFutures);

      // Populate the map with results
      for (var result in results) {
        emailsByContact[result.key] = result.value;
      }

      if (mounted) {
        setState(() {
          _vipEmailsByContact = emailsByContact;
          _isLoading = false;
          _isRefreshing = false;
        });
        _cacheVipEmails(); // Cache results
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

  // Helper method to get contact name from email
  String? _getContactName(String email) {
    final contact = _vipContacts.firstWhere(
      (c) => c.email.toLowerCase() == email.toLowerCase(),
      orElse: () => Contact(id: '', name: email, email: email),
    );
    return contact.name;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Only show shimmer for initial loading when there's no data
    if (_isLoading && _vipEmailsByContact.isEmpty && !_loadingFromCache) {
      return const EmailShimmerList(itemCount: 5);
    }

    // Empty state with "Add VIP Contact" button
    if (_vipEmailsByContact.isEmpty) {
      return _buildEmptyState();
    }

    // If no contact is selected, show the folders view
    if (_selectedContactEmail == null) {
      return _buildFoldersView();
    } else {
      // Show emails from the selected contact
      return _buildEmailsView();
    }
  }

  Widget _buildEmptyState() {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _loadVipEmails(refresh: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
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
              const Center(
                child: Text(
                  'Pull down to refresh',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
        _buildAddContactFAB(),
      ],
    );
  }

  Widget _buildFoldersView() {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _loadVipEmails(refresh: true),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _vipContacts.length,
            itemBuilder: (context, index) {
              final contact = _vipContacts[index];
              final contactEmails =
                  _vipEmailsByContact[contact.email.toLowerCase()] ?? [];

              return ContactFolderItem(
                contact: contact,
                emailCount: contactEmails.length,
                onTap: () {
                  setState(() {
                    _selectedContactEmail = contact.email.toLowerCase();
                  });
                },
              );
            },
          ),
        ),
        _buildAddContactFAB(),
      ],
    );
  }

  Widget _buildEmailsView() {
    final emails =
        _vipEmailsByContact[_selectedContactEmail!.toLowerCase()] ?? [];
    final contactName = _getContactName(_selectedContactEmail!);

    return ContactEmailList(
      emails: emails,
      contactEmail: _selectedContactEmail!,
      contactName: contactName,
      onBackPressed: () {
        setState(() {
          _selectedContactEmail = null;
        });
      },
      onRefresh: () => _loadVipEmails(refresh: true),
    );
  }

  Widget _buildAddContactFAB() {
    return Positioned(
      bottom: 16,
      right: 16,
      child: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddContactScreen()),
          );

          if (result == true) {
            _loadVipEmails();
          }
        },
        tooltip: 'Add VIP Contact',
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
