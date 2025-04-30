import 'package:flutter/material.dart';
import 'package:mail_merge/features/email/widgets/email_item.dart';
import 'package:mail_merge/features/email/widgets/email_shimmer.dart';
import 'package:mail_merge/features/email/services/unified_email_service.dart';
import 'package:mail_merge/user/authentication/add_email_accounts.dart';
import 'package:mail_merge/user/authentication/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class EmailListScreen extends StatefulWidget {
  final String accessToken;

  const EmailListScreen({super.key, required this.accessToken});

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

  // Add cache flag
  bool _loadingFromCache = false;

  @override
  bool get wantKeepAlive => true; // Keep state when switching tabs

  void checkAuthAndClearIfNeeded() async {
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
    _emailService = UnifiedEmailService();  // No need to pass access token anymore
    checkAuthAndClearIfNeeded();

    _loadCachedEmails(); // Load from cache first
    fetchEmails(); // Then fetch fresh data

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        fetchEmails();
      }
    });
  }

  // Load emails from cache
  Future<void> _loadCachedEmails() async {
    try {
      _loadingFromCache = true;
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cached_emails');

      if (cachedData != null) {
        final List<dynamic> decodedData = jsonDecode(cachedData);
        setState(() {
          emailData = List<Map<String, dynamic>>.from(
            decodedData.map((item) => Map<String, dynamic>.from(item)),
          );
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
      await prefs.setString('cached_emails', jsonEncode(emailData));
    } catch (e) {
      print('Error caching emails: $e');
    }
  }

  @override
  void didUpdateWidget(EmailListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Nothing to update - UnifiedEmailService handles access tokens internally
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchEmails({bool refresh = false}) async {
    if (!_hasMore && !refresh) return;

    if (_isLoading && !refresh) return; // Prevent multiple simultaneous requests

    setState(() {
      _isLoading = true;
    });

    try {
      final emails = await _emailService.fetchUnifiedEmails(
        pageToken: refresh ? null : _nextPageToken,
      );

      setState(() {
        if (refresh) {
          emailData = emails;
        } else {
          emailData.addAll(emails);
        }
        // For simplicity, we'll assume no pagination in the unified approach
        _nextPageToken = null;
        _hasMore = false; // For now, disable infinite scroll
        _isLoading = false;
      });

      // Cache the results for next time
      _cacheEmails();
    } catch (e) {
      print('Error fetching emails: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // More robust check: verify both accessToken and authentication state
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

    if (_isLoading && emailData.isEmpty && !_loadingFromCache) {
      return const EmailShimmerList(); // Use default or automatically calculated item count
    }

    return RefreshIndicator(
      onRefresh: () => fetchEmails(refresh: true),
      child:
          emailData.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: emailData.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
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

  Widget _buildEmptyState() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(), // Ensure pull to refresh works with empty list
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
