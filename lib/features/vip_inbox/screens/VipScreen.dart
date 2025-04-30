import 'package:flutter/material.dart';
import 'package:mail_merge/features/vip_inbox/services/contact_service.dart';
import 'package:mail_merge/features/email/services/unified_email_service.dart';
import 'package:mail_merge/user/authentication/google_sign_in.dart';
import 'package:mail_merge/features/vip_inbox/screens/contacts_screen.dart';
import 'package:mail_merge/features/vip_inbox/screens/add_contact_screen.dart';
import 'package:mail_merge/features/email/widgets/email_shimmer.dart';
import 'package:mail_merge/features/vip_inbox/models/contact.dart';
import 'package:mail_merge/features/vip_inbox/widgets/contact_folder_item.dart';
import 'package:mail_merge/features/vip_inbox/widgets/contact_email_list.dart';
import 'package:mail_merge/core/services/event_bus.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// A screen that displays emails from VIP contacts organized into folders
/// Each folder represents a VIP contact and contains all emails from that contact
class VipScreen extends StatefulWidget {
  // Make accountId optional to support both unified and account-specific view
  final String? accountId;

  const VipScreen({super.key, this.accountId});

  @override
  State<VipScreen> createState() => _VipScreenState();
}

class _VipScreenState extends State<VipScreen>
    with AutomaticKeepAliveClientMixin {
  // Map to store emails grouped by contact
  // Key: contact email, Value: list of emails from that contact
  Map<String, List<Map<String, dynamic>>> _vipEmailsByContact = {};

  // List of all VIP contacts
  List<Contact> _vipContacts = [];

  // Loading and state flags
  bool _isLoading = true; // Used for initial loading
  bool _isRefreshing = false; // Used for pull-to-refresh
  String? _accessToken; // Google API access token
  bool _loadingFromCache = false; // Indicates we're loading data from cache

  // Currently selected contact (for showing their emails)
  // When null, we show the folders view instead of emails
  String? _selectedContactEmail;

  // Track the current account ID to detect changes
  String? _currentAccountId;

  @override
  bool get wantKeepAlive => true;

  StreamSubscription? _accountSubscription;

  @override
  void initState() {
    super.initState();
    // Store initial account ID
    _currentAccountId = widget.accountId;

    _loadCachedVipEmails(); // First load from cache for instant display
    _loadVipEmails(); // Then fetch fresh data from the server
    _checkAuthAndClearDataIfNeeded(); // Verify authentication status

    // Listen for account events
    _accountSubscription = eventBus.on<AccountRemovedEvent>().listen((_) {
      // Refresh VIP emails when an account is removed
      if (mounted) {
        _loadVipEmails(refresh: true);
      }
    });
  }

  // Add didUpdateWidget to detect account changes
  @override
  void didUpdateWidget(VipScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If account ID changed, refresh emails
    if (widget.accountId != _currentAccountId) {
      print(
        'DEBUG: VipScreen account ID changed from $_currentAccountId to ${widget.accountId}',
      );
      _currentAccountId = widget.accountId;
      _loadVipEmails(refresh: true);
    }
  }

  /// Checks if user is authenticated and clears data if not
  /// This prevents showing emails after logging out
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

  /// Loads cached VIP emails from SharedPreferences for faster startup
  /// This provides immediate content while fresh data is being fetched
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

        // Apply account filtering to cached data if needed
        if (widget.accountId != null && widget.accountId!.isNotEmpty) {
          // Filter each contact's emails to only include those from the selected account
          final filteredEmailsByContact =
              <String, List<Map<String, dynamic>>>{};

          _vipEmailsByContact.forEach((contactEmail, emails) {
            final filteredEmails =
                emails
                    .where((email) => email['accountId'] == widget.accountId)
                    .toList();

            if (filteredEmails.isNotEmpty) {
              filteredEmailsByContact[contactEmail] = filteredEmails;
            }
          });

          _vipEmailsByContact = filteredEmailsByContact;
        }
      }

      setState(() {
        _loadingFromCache = false;
      });
    } catch (e) {
      print('Error loading cached VIP emails: $e');
      _loadingFromCache = false;
    }
  }

  /// Saves emails and contacts to cache for faster loading next time
  /// This ensures data is immediately available on app restart
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

  /// Loads VIP emails from the server
  /// This is the main data fetching method that retrieves emails for all VIP contacts
  Future<void> _loadVipEmails({bool refresh = false}) async {
    // Store the current selected contact before refreshing
    final currentSelectedContact = _selectedContactEmail;

    // Handle loading state
    if (refresh) {
      setState(() {
        _isRefreshing = true;
      });
    } else if (!_isLoading) {
      setState(() => _isLoading = true);
    }

    try {
      // Get VIP contacts
      final vipContacts = await ContactService.getVipContacts();
      _vipContacts = vipContacts;

      // If no VIP contacts, clear emails and update state
      if (vipContacts.isEmpty) {
        setState(() {
          _vipEmailsByContact = {};
          _isLoading = false;
          _isRefreshing = false;
          if (_selectedContactEmail != null) {
            _selectedContactEmail = null;
          }
        });
        _cacheVipEmails(); // Cache empty results
        return;
      }

      // Get email service
      final emailService = UnifiedEmailService();

      // Get all email addresses of VIP contacts
      final vipEmailAddresses = vipContacts.map((c) => c.email).toList();

      // Fetch emails for all VIP contacts using the unified service
      final allEmailsByContact = await emailService.fetchVipEmailsByContact(
        vipEmailAddresses,
        maxResults: 10, // Limit per contact for better performance
      );

      // Apply account filtering if needed
      Map<String, List<Map<String, dynamic>>> filteredEmailsByContact;

      if (widget.accountId != null && widget.accountId!.isNotEmpty) {
        // Filter each contact's emails to only include those from the selected account
        filteredEmailsByContact = <String, List<Map<String, dynamic>>>{};

        allEmailsByContact.forEach((contactEmail, emails) {
          final filteredEmails =
              emails
                  .where((email) => email['accountId'] == widget.accountId)
                  .toList();

          if (filteredEmails.isNotEmpty) {
            filteredEmailsByContact[contactEmail] = filteredEmails;
          }
        });
      } else {
        // No filtering needed, use all emails
        filteredEmailsByContact = allEmailsByContact;
      }

      if (mounted) {
        setState(() {
          _vipEmailsByContact = filteredEmailsByContact;
          _isLoading = false;
          _isRefreshing = false;

          // If the contact we were viewing no longer exists in the results,
          // then reset the selected contact
          if (_selectedContactEmail != null &&
              !filteredEmailsByContact.containsKey(
                _selectedContactEmail!.toLowerCase(),
              )) {
            _selectedContactEmail = null;
          } else if (currentSelectedContact != null &&
              filteredEmailsByContact.containsKey(
                currentSelectedContact.toLowerCase(),
              )) {
            // Restore the previously selected contact if it still exists
            _selectedContactEmail = currentSelectedContact;
          }
        });

        // Cache all results for future use
        _cacheVipEmails();
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

  /// Gets a contact's name from their email address
  /// Used to display proper names in the UI instead of just email addresses
  String? _getContactName(String email) {
    final contact = _vipContacts.firstWhere(
      (c) => c.email.toLowerCase() == email.toLowerCase(),
      orElse: () => Contact(id: '', name: email, email: email),
    );
    return contact.name;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    // Show shimmer loading effect when loading initially (no cached data)
    if (_isLoading && _vipEmailsByContact.isEmpty && !_loadingFromCache) {
      return const EmailShimmerList(itemCount: 5);
    }

    // Show empty state when there are no VIP emails
    if (_vipEmailsByContact.isEmpty) {
      return _buildEmptyState();
    }

    // Navigation logic: show folders or emails based on selection
    if (_selectedContactEmail == null) {
      return _buildFoldersView(); // Show contact folders
    } else {
      return _buildEmailsView(); // Show emails from selected contact
    }
  }

  /// Builds the empty state UI when there are no VIP contacts
  /// Displays helpful instructions and buttons to add VIP contacts
  Widget _buildEmptyState() {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () => _loadVipEmails(refresh: true),
          child: ListView(
            physics:
                const AlwaysScrollableScrollPhysics(), // Enable scrolling on empty list
            children: [
              SizedBox(height: MediaQuery.of(context).size.height / 4),
              // Star icon
              const Icon(Icons.star, size: 80, color: Colors.amber),
              const SizedBox(height: 16),
              // Title
              const Text(
                'No VIP emails',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // Explanation
              const Text(
                'Add contacts to your VIP list to see their emails here',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              // Button to manage contacts
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
              // Pull to refresh instruction
              const Center(
                child: Text(
                  'Pull down to refresh',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
        // Floating action button to add contact
        _buildAddContactFAB(),
      ],
    );
  }

  /// Builds the folders view UI that shows all VIP contacts as folders
  /// Each folder displays the contact's info and email count
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

              // Skip contacts with no emails (after filtering)
              if (contactEmails.isEmpty) {
                return const SizedBox.shrink();
              }

              // Use the modular ContactFolderItem widget for each folder
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
        // Floating action button to add contact
        _buildAddContactFAB(),
      ],
    );
  }

  /// Builds the emails view UI that shows emails from a selected contact
  /// Displays a back button to return to the folders view
  Widget _buildEmailsView() {
    final emails =
        _vipEmailsByContact[_selectedContactEmail!.toLowerCase()] ?? [];
    final contactName = _getContactName(_selectedContactEmail!);

    // Use the modular ContactEmailList widget to display emails
    return ContactEmailList(
      emails: emails,
      contactEmail: _selectedContactEmail!,
      contactName: contactName,
      onBackPressed: () {
        setState(() {
          _selectedContactEmail = null; // Return to folders view
        });
      },
      onRefresh: () => _loadVipEmails(refresh: true),
    );
  }

  /// Builds the floating action button for adding VIP contacts
  /// Used across multiple views for consistency
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
            _loadVipEmails(); // Reload data if a contact was added
          }
        },
        tooltip: 'Add VIP Contact',
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
