import 'package:flutter/material.dart';
import 'package:mail_merge/features/email/widgets/email_item.dart';
import 'package:mail_merge/features/email/widgets/email_shimmer.dart';
import 'package:mail_merge/features/email/services/unified_email_service.dart';
import 'package:mail_merge/user/authentication/add_email_accounts.dart';
import 'package:mail_merge/user/authentication/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:mail_merge/core/services/event_bus.dart';
import 'dart:async';

class EmailListScreen extends StatefulWidget {
  final String accessToken;
  final String? accountId;
  final bool forceLoading; // Add this parameter

  const EmailListScreen({
    super.key,
    required this.accessToken,
    this.accountId,
    this.forceLoading = false, // Default to false
  });

  @override
  State<EmailListScreen> createState() => EmailListScreenState();
}

class EmailListScreenState extends State<EmailListScreen>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> emailData = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _nextPageToken;
  final ScrollController _scrollController = ScrollController();
  late UnifiedEmailService _emailService;
  bool _loadingFromCache = false;
  StreamSubscription? _accountSubscription;

  // Track the current account ID to detect changes
  String? _currentAccountId;

  @override
  bool get wantKeepAlive => true; // Keep state when switching tabs

  void checkAuthAndClearIfNeeded() async {
    // Check if user is authenticated
    final user = await getCurrentUser();

    if (user == null && mounted) {
      // User is not logged in, clear everything
      setState(() {
        emailData.clear();
        _nextPageToken = null;
        _hasMore = true;
        _isLoading = false;
      });

      // Also clear the cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_emails');
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize email service
    _emailService = UnifiedEmailService();
    checkAuthAndClearIfNeeded();

    // Store initial account ID
    _currentAccountId = widget.accountId;

    // Load from cache first for immediate display
    _loadCachedEmails();

    // Then fetch fresh data from server
    fetchEmails();

    // Set up infinite scrolling
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        fetchEmails();
      }
    });

    // Listen for account removal events
    _accountSubscription = eventBus.on<AccountRemovedEvent>().listen((_) {
      // Refresh emails when an account is removed
      if (mounted) {
        fetchEmails(refresh: true);
      }
    });
  }

  // Check if account ID has changed and reload emails if needed
  @override
  void didUpdateWidget(EmailListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If account ID changed, refresh emails
    if (widget.accountId != _currentAccountId) {
      _currentAccountId = widget.accountId;
      fetchEmails(refresh: true);
    }
  }

  // Load emails from cache
  Future<void> _loadCachedEmails() async {
    try {
      _loadingFromCache = true;
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cached_emails');

      if (cachedData != null) {
        final List<dynamic> decodedData = jsonDecode(cachedData);

        // Convert to list of Maps
        final allEmails = List<Map<String, dynamic>>.from(
          decodedData.map((item) => Map<String, dynamic>.from(item)),
        );

        // If account ID is specified, filter emails for that account
        final filteredEmails =
            widget.accountId != null && widget.accountId!.isNotEmpty
                ? allEmails
                    .where((email) => email['accountId'] == widget.accountId)
                    .toList()
                : allEmails;

        setState(() {
          emailData = filteredEmails;
        });
      }
      _loadingFromCache = false;
    } catch (e) {
      print('Error loading cached emails: $e');
      _loadingFromCache = false;
    }
  }

  // Cache emails for faster loading next time
  Future<void> _cacheEmails() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Create a JSON-safe copy of the email data by removing non-serializable fields
      final jsonSafeEmails =
          emailData.map((email) {
            final emailCopy = Map<String, dynamic>.from(email);
            // Remove the DateTime object that can't be serialized
            emailCopy.remove('_dateTime');
            return emailCopy;
          }).toList();

      // Cache the JSON-safe version
      await prefs.setString('cached_emails', jsonEncode(jsonSafeEmails));
    } catch (e) {
      print('Error caching emails: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _accountSubscription?.cancel();
    super.dispose();
  }

  // Fetch emails with account filtering
  Future<void> fetchEmails({bool refresh = false}) async {
    // Skip if we're already at the end and not refreshing
    if (!_hasMore && !refresh) return;

    // Skip if already loading and not forcing refresh
    if (_isLoading && !refresh) return;

    // Add a mounted check before first setState
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Fetch all emails or use pagination token
      final allEmails = await _emailService.fetchUnifiedEmails(
        pageToken: refresh ? null : _nextPageToken,
      );

      // Debug logging
      print('DEBUG: Fetched ${allEmails.length} emails');
      if (allEmails.isNotEmpty) {
        print('DEBUG: First email account ID: ${allEmails.first['accountId']}');
      }
      print('DEBUG: Current selected account ID: ${widget.accountId}');

      // Filter emails if account ID is specified
      final filteredEmails =
          widget.accountId != null && widget.accountId!.isNotEmpty
              ? allEmails.where((email) {
                // Get the account ID from the email
                final emailAccountId = email['accountId']?.toString();
                print(
                  'DEBUG: Comparing email account: $emailAccountId with selected: ${widget.accountId}',
                );
                // Compare with the selected account ID
                return emailAccountId == widget.accountId;
              }).toList()
              : allEmails;

      print('DEBUG: After filtering, have ${filteredEmails.length} emails');

      // Add another mounted check before the second setState
      if (!mounted) return;

      setState(() {
        if (refresh) {
          // Replace existing emails on refresh
          emailData = filteredEmails;
        } else {
          // Append new emails to existing list
          emailData.addAll(filteredEmails);
        }

        // For now, we'll assume no pagination with the unified approach
        _nextPageToken = null;
        _hasMore = false; // Disable infinite scroll for simplicity
        _isLoading = false;
      });

      // Cache the complete results (unfiltered) for future use
      _cacheEmails();
    } catch (e) {
      print('Error fetching emails: $e');
      // Add another mounted check before the error setState
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void setShimmerState(bool isLoading) {
    if (mounted) {
      setState(() {
        _isLoading = isLoading;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Always show shimmer when forceLoading is true
    if (widget.forceLoading) {
      return const EmailShimmerList();
    }

    // Rest of your existing build code...
    if (_isLoading && emailData.isEmpty && !_loadingFromCache) {
      return const EmailShimmerList();
    }

    // If not authenticated, show sign-in prompt
    if (widget.accessToken.isEmpty) {
      // Clear cached data if user is not authenticated
      if (emailData.isNotEmpty) {
        emailData.clear();
        _nextPageToken = null;
        _hasMore = true;
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Sign in to view your emails"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddEmailAccountsPage(),
                  ),
                );
              },
              child: const Text("Add Email Account"),
            ),
          ],
        ),
      );
    }

    // Show shimmer loading effect when first loading with no cached data
    if (_isLoading && emailData.isEmpty && !_loadingFromCache) {
      return const EmailShimmerList(); // Shows animated loading placeholders
    }

    // Main email list with pull-to-refresh
    return RefreshIndicator(
      onRefresh: () => fetchEmails(refresh: true),
      child:
          emailData.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                itemCount: emailData.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  // Show loading indicator at the bottom during pagination
                  if (index == emailData.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  // Don't access emailData if index is out of bounds
                  if (index >= emailData.length) {
                    return const SizedBox.shrink();
                  }

                  // Display the email item
                  final email = emailData[index];
                  return EmailItem(
                    name: email["name"] ?? "Unknown",
                    subject: email["message"] ?? "",
                    time: email["time"] ?? "",
                    snippet: email["snippet"] ?? "",
                    avatar:
                        email["avatar"] ??
                        "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png",
                    emailData: email, // Pass the complete email data
                  );
                },
              ),
    );
  }

  // Empty state when no emails are found
  Widget _buildEmptyState() {
    // Create a scrollable empty state to enable pull-to-refresh
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height / 4),
        const Icon(Icons.inbox_outlined, size: 80, color: Colors.grey),
        const SizedBox(height: 16),
        const Text(
          'No emails found',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pull down to refresh',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }
}
