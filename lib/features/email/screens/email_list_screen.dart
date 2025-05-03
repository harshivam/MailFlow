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

  // Last applied keyword for filtering
  String? _lastAppliedKeyword;

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

    // Set loading state
    setState(() {
      _isLoading = true;

      // Important: Don't clear emailData here unless refreshing
      // This keeps the current emails visible while fetching new ones
      if (refresh) {
        // Only clear emails if we're explicitly refreshing
        // This gives a better UX by showing the user their existing content
        // while loading fresh data
        emailData = [];

        // ONLY clear filter if explicitly requested
        // Don't reset _lastAppliedKeyword here
      }
    });

    try {
      // Fetch emails from unified service
      final allEmails = await _emailService.fetchUnifiedEmails(
        pageToken: refresh ? null : _nextPageToken,
        onlyWithAttachments: false,
      );

      // Filter emails for this account if needed
      var filteredEmails =
          widget.accountId != null && widget.accountId!.isNotEmpty
              ? allEmails
                  .where((email) => email['accountId'] == widget.accountId)
                  .toList()
              : allEmails;

      // IMPORTANT: Apply keyword filter if there's an active filter
      if (_lastAppliedKeyword != null && _lastAppliedKeyword!.isNotEmpty) {
        print('DEBUG: Re-applying filter for keyword: $_lastAppliedKeyword');
        final keywordLower = _lastAppliedKeyword!.toLowerCase();

        filteredEmails =
            filteredEmails.where((email) {
              final subject = (email['message'] ?? '').toString().toLowerCase();
              final body =
                  (email['plainTextBody'] ?? '').toString().toLowerCase();
              final snippet = (email['snippet'] ?? '').toString().toLowerCase();
              final sender = (email['name'] ?? '').toString().toLowerCase();
              final senderEmail =
                  (email['from'] ?? '').toString().toLowerCase();

              return subject.contains(keywordLower) ||
                  body.contains(keywordLower) ||
                  snippet.contains(keywordLower) ||
                  sender.contains(keywordLower) ||
                  senderEmail.contains(keywordLower);
            }).toList();
      }

      // Check if widget is still mounted
      if (!mounted) return;

      // Update UI with new emails
      setState(() {
        if (refresh) {
          // Replace existing emails on refresh
          emailData = filteredEmails;
        } else {
          // Append new emails to existing list
          emailData.addAll(filteredEmails);
        }

        _nextPageToken = null;
        _hasMore = false;
        _isLoading = false;
      });

      // Cache emails in the background
      _cacheEmails();
    } catch (e) {
      print('Error fetching emails: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Make the filterByKeyword method more robust
  Future<void> filterByKeyword(String keyword) async {
    print('DEBUG: filterByKeyword called with "$keyword"');

    if (keyword.isEmpty) {
      print('DEBUG: Empty keyword, refreshing all emails');
      fetchEmails(refresh: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Get all emails (or use current set if already loaded)
      List<Map<String, dynamic>> allEmails;
      if (emailData.isEmpty) {
        print('DEBUG: No existing emails, fetching from service');
        allEmails = await _emailService.fetchUnifiedEmails(
          onlyWithAttachments: false,
        );
        print('DEBUG: Fetched ${allEmails.length} emails from service');
      } else {
        print('DEBUG: Using ${emailData.length} existing emails for filtering');
        allEmails = List.from(emailData);
      }

      // Now filter emails that match the keyword
      print('DEBUG: Filtering emails with keyword: "$keyword"');
      final filteredEmails =
          allEmails.where((email) {
            final subject = (email['message'] ?? '').toString().toLowerCase();
            final body =
                (email['plainTextBody'] ?? '').toString().toLowerCase();
            final snippet = (email['snippet'] ?? '').toString().toLowerCase();
            final sender = (email['name'] ?? '').toString().toLowerCase();
            final senderEmail = (email['from'] ?? '').toString().toLowerCase();

            final keywordLower = keyword.toLowerCase();

            // Check if any field contains the keyword
            return subject.contains(keywordLower) ||
                body.contains(keywordLower) ||
                snippet.contains(keywordLower) ||
                sender.contains(keywordLower) ||
                senderEmail.contains(keywordLower);
          }).toList();

      print('DEBUG: Found ${filteredEmails.length} emails matching "$keyword"');

      if (!mounted) {
        print('DEBUG: Widget no longer mounted, aborting filter update');
        return;
      }

      setState(() {
        emailData = filteredEmails;
        _isLoading = false;
        _lastAppliedKeyword = keyword; // Store the keyword

        // Important: Reset pagination variables so user can still refresh
        _hasMore = false;
        _nextPageToken = null;
      });

      // If no results found, show a message
      if (filteredEmails.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No emails found matching "$keyword"')),
        );
      } else {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Found ${filteredEmails.length} emails matching "$keyword"',
            ),
          ),
        );
      }
    } catch (e) {
      print('ERROR filtering emails: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void setShimmerState(bool isLoading) {
    if (mounted) {
      setState(() {
        _isLoading = isLoading;
      });
    }
  }

  void clearFilter() {
    setState(() {
      _lastAppliedKeyword = null;
    });
    fetchEmails(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Check for active filters and show clear button if needed
    final isFiltered =
        (_lastAppliedKeyword != null && _lastAppliedKeyword!.isNotEmpty);

    // Always show shimmer when forceLoading is true
    if (widget.forceLoading) {
      return const EmailShimmerList();
    }

    // Rest of your existing build code...

    // Modified RefreshIndicator section to include clear filter button when needed
    return Column(
      children: [
        // Show filter status bar if a filter is applied
        if (isFiltered)
          Container(
            color: Colors.blue.withOpacity(0.1),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.filter_list, size: 18, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Filtered by: $_lastAppliedKeyword',
                  style: TextStyle(color: Colors.blue),
                ),
                Spacer(),
                TextButton(
                  onPressed: () => clearFilter(),
                  child: Text('CLEAR FILTER'),
                ),
              ],
            ),
          ),

        // Main email list
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              // If there's a filter, refresh with the filter preserved
              if (_lastAppliedKeyword != null &&
                  _lastAppliedKeyword!.isNotEmpty) {
                await fetchEmails(refresh: true);
                return;
              } else {
                // Regular refresh with no filter
                return fetchEmails(refresh: true);
              }
            },
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
          ),
        ),
      ],
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
