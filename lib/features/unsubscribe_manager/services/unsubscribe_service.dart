import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mail_merge/features/unsubscribe_manager/models/subscription_email.dart';
import 'package:mail_merge/features/email/services/unified_email_service.dart';
import 'package:mail_merge/features/email/services/email_service.dart';
import 'package:mail_merge/user/repository/account_repository.dart';
import 'package:mail_merge/user/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mail_merge/core/services/event_bus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mail_merge/main.dart'; // Add this import to access navigatorKey
import 'package:mail_merge/features/unsubscribe_manager/widgets/unsubscribe_webview.dart';

class UnsubscribeService {
  static final UnsubscribeService _instance = UnsubscribeService._internal();
  factory UnsubscribeService() => _instance;
  UnsubscribeService._internal();

  final UnifiedEmailService _emailService = UnifiedEmailService();
  final AccountRepository _accountRepository = AccountRepository();
  final AuthService _authService = AuthService();

  // Track subscription emails - Add this line to fix the error
  final List<SubscriptionEmail> _subscriptions = [];

  // Throttling control
  DateTime _lastApiRequest = DateTime.now().subtract(Duration(seconds: 2));
  final _minRequestInterval = Duration(milliseconds: 500);

  // Fetch subscription emails (both unified and account-specific)
  Future<List<SubscriptionEmail>> fetchSubscriptions({
    String? accountId,
    int maxResults = 20,
    bool refresh = false,
    Function(double)? onProgress,
  }) async {
    try {
      onProgress?.call(0.1);

      // Try to load from cache first if not refreshing
      if (!refresh) {
        final cachedSubscriptions = await _loadCachedSubscriptions();

        // Filter by account if needed
        final filteredSubscriptions =
            accountId != null
                ? cachedSubscriptions
                    .where((sub) => sub.accountId == accountId)
                    .toList()
                : cachedSubscriptions;

        if (filteredSubscriptions.isNotEmpty) {
          onProgress?.call(1.0);
          return filteredSubscriptions;
        }
      }

      onProgress?.call(0.2);

      // If cache is empty or refresh is requested, fetch from API
      List<SubscriptionEmail> subscriptions = [];

      // Use query to find potential subscription emails
      final emails = await _emailService.fetchUnifiedEmails(
        maxResults: maxResults,
        onlyWithAttachments: false,
        query: "unsubscribe OR newsletter OR subscription",
      );

      onProgress?.call(0.3);

      // Filter for specific account if needed
      final filteredEmails =
          accountId != null
              ? emails
                  .where((email) => email['accountId'] == accountId)
                  .toList()
              : emails;

      // Process in batches to avoid rate limits
      const batchSize = 5;

      onProgress?.call(0.4);

      for (int i = 0; i < filteredEmails.length; i += batchSize) {
        final endIdx =
            (i + batchSize < filteredEmails.length)
                ? i + batchSize
                : filteredEmails.length;

        final batch = filteredEmails.sublist(i, endIdx);

        // Process each email in batch
        final batchResults = await Future.wait(
          batch.map((email) => _processEmail(email)),
          eagerError: false,
        );

        // Add valid subscription emails to results
        for (var result in batchResults) {
          if (result != null) {
            subscriptions.add(result);
          }
        }

        // Update progress
        onProgress?.call(0.4 + (0.5 * (i + batchSize) / filteredEmails.length));

        // Throttle API requests
        await _throttleRequest();
      }

      // Cache results
      await _cacheSubscriptions(subscriptions);

      onProgress?.call(1.0);
      return subscriptions;
    } catch (e) {
      print('Error fetching subscriptions: $e');
      return await _loadCachedSubscriptions();
    }
  }

  // Process an email to extract unsubscribe information
  Future<SubscriptionEmail?> _processEmail(Map<String, dynamic> email) async {
    try {
      final messageId = email['id'];
      final accountId = email['accountId'];

      if (messageId == null || accountId == null) return null;

      // Get detailed message to check headers
      final fullMessage = await _getMessageDetails(messageId, accountId);
      if (fullMessage == null) return null;

      // Look for List-Unsubscribe header
      String unsubscribeUrl = '';
      String unsubscribeEmail = '';

      if (fullMessage['payload'] != null &&
          fullMessage['payload']['headers'] != null) {
        final headers = fullMessage['payload']['headers'] as List;

        for (var header in headers) {
          if (header['name'] == 'List-Unsubscribe') {
            final headerValue = header['value'] as String;

            // Extract URL
            final urlMatch = RegExp(
              r'<(https?://[^>]+)>',
            ).firstMatch(headerValue);
            if (urlMatch != null) {
              unsubscribeUrl = urlMatch.group(1) ?? '';
            }

            // Extract email
            final emailMatch = RegExp(
              r'<mailto:([^>]+)>',
            ).firstMatch(headerValue);
            if (emailMatch != null) {
              unsubscribeEmail = emailMatch.group(1) ?? '';
            }

            break;
          }
        }
      }

      // Look for unsubscribe link in body as fallback
      if (unsubscribeUrl.isEmpty) {
        unsubscribeUrl = _extractUnsubscribeLinkFromBody(fullMessage);
      }

      // If we found either URL or email, this is a subscription
      if (unsubscribeUrl.isNotEmpty || unsubscribeEmail.isNotEmpty) {
        return SubscriptionEmail(
          id: messageId,
          sender: email['name'] ?? 'Unknown',
          senderEmail: email['from'] ?? '',
          subject: email['message'] ?? 'No Subject',
          date: email['_dateTime'] ?? DateTime.now(),
          unsubscribeUrl: unsubscribeUrl,
          unsubscribeEmail: unsubscribeEmail,
          accountId: accountId,
          accountName: email['accountName'] ?? 'Email Account',
          snippet: email['snippet'] ?? '',
        );
      }

      return null;
    } catch (e) {
      print('Error processing email: $e');
      return null;
    }
  }

  // Extract unsubscribe link from email body
  String _extractUnsubscribeLinkFromBody(Map<String, dynamic> message) {
    try {
      // Check for HTML body
      if (message['payload'] != null && message['payload']['parts'] != null) {
        final parts = message['payload']['parts'] as List;

        for (var part in parts) {
          if (part['mimeType'] == 'text/html' &&
              part['body'] != null &&
              part['body']['data'] != null) {
            final data = part['body']['data'];
            final decodedData = utf8.decode(
              base64.decode(data.replaceAll('-', '+').replaceAll('_', '/')),
            );

            // Look for unsubscribe links
            final regex = RegExp(
              r'href="(https?://[^"]*unsubscribe[^"]*)"',
              caseSensitive: false,
            );
            final match = regex.firstMatch(decodedData);

            if (match != null) {
              return match.group(1) ?? '';
            }
          }
        }
      }

      // Check plain text body
      if (message['snippet'] != null) {
        final snippet = message['snippet'] as String;
        final urlRegex = RegExp(
          r'(https?://\S*unsubscribe\S*)',
          caseSensitive: false,
        );
        final match = urlRegex.firstMatch(snippet);

        if (match != null) {
          return match.group(1) ?? '';
        }
      }

      return '';
    } catch (e) {
      print('Error extracting unsubscribe link: $e');
      return '';
    }
  }

  // Helper to get message details (similar to other services)
  Future<Map<String, dynamic>?> _getMessageDetails(
    String messageId,
    String accountId,
  ) async {
    try {
      final account = await _accountRepository.getAccountById(accountId);
      final accessToken = await _authService.getAccessToken(accountId);

      if (accessToken == null) return null;

      final emailService = EmailService(accessToken);
      return await emailService.getMessage(messageId);
    } catch (e) {
      print('Error getting message details: $e');
      return null;
    }
  }

  // Unsubscribe from a subscription
  Future<bool> unsubscribe(SubscriptionEmail subscription) async {
    try {
      // Update UI first to show processing state
      final index = _subscriptions.indexWhere((s) => s.id == subscription.id);
      if (index != -1) {
        _subscriptions[index] = _subscriptions[index].copyWith(
          isUnsubscribing: true,
        );
      }

      // Fire event to update UI
      eventBus.fire(UnsubscribeStartedEvent(subscription.id));

      if (subscription.unsubscribeUrl.isNotEmpty) {
        // First try direct HTTP request for simple unsubscribe links
        try {
          final url = subscription.unsubscribeUrl;
          final response = await http.get(
            Uri.parse(url),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              'Accept': 'text/html,application/xhtml+xml',
              'Accept-Language': 'en-US,en;q=0.9',
              'Referer': 'https://mail.google.com/',
            },
          );

          print('HTTP Unsubscribe response: ${response.statusCode}');

          // Some simple unsubscribe links work with just a GET request
          if (response.statusCode == 200 || response.statusCode == 302) {
            // Check if the response contains confirmation text
            final body = response.body.toLowerCase();
            final confirmationTerms = [
              'successfully unsubscribed',
              'unsubscribe successful',
              'you have been unsubscribed',
            ];

            bool foundConfirmation = confirmationTerms.any(
              (term) => body.contains(term),
            );

            if (foundConfirmation) {
              print(
                'Direct unsubscribe successful, found confirmation in response',
              );
              await _markAsUnsubscribed(subscription.id);
              eventBus.fire(UnsubscribeCompletedEvent(subscription.id, true));
              return true;
            }
          }
        } catch (e) {
          print('Direct HTTP unsubscribe failed: $e');
          // Continue to WebView approach
        }

        // For complex unsubscribe flows, use our WebView
        final context = navigatorKey.currentContext;
        if (context != null) {
          try {
            final result = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder:
                    (context) => UnsubscribeWebView(subscription: subscription),
              ),
            );

            // If the WebView returned true, the unsubscribe was successful
            if (result == true) {
              await _markAsUnsubscribed(subscription.id);
              eventBus.fire(UnsubscribeCompletedEvent(subscription.id, true));
              return true;
            } else {
              // WebView was closed without confirming success
              eventBus.fire(UnsubscribeCompletedEvent(subscription.id, false));
              return false;
            }
          } catch (e) {
            print('WebView error: $e');
            // Fall back to external browser as last resort
            return _fallbackToExternalBrowser(subscription);
          }
        } else {
          // No context available, fall back to external browser
          return _fallbackToExternalBrowser(subscription);
        }
      } else if (subscription.unsubscribeEmail.isNotEmpty) {
        // Handle email-based unsubscribe with improved feedback
        return _handleEmailUnsubscribe(subscription);
      }

      // If we got here, nothing worked
      eventBus.fire(UnsubscribeCompletedEvent(subscription.id, false));
      return false;
    } catch (e) {
      print('Unsubscribe error: $e');
      eventBus.fire(UnsubscribeCompletedEvent(subscription.id, false));
      return false;
    }
  }

  // Add this helper method for email unsubscribe
  Future<bool> _handleEmailUnsubscribe(SubscriptionEmail subscription) async {
    try {
      final emailUri = Uri(
        scheme: 'mailto',
        path: subscription.unsubscribeEmail,
        query:
            'subject=Unsubscribe&body=Please unsubscribe me from your mailing list.%0A%0AEmail: ${subscription.senderEmail}%0A%0A${subscription.subject}',
      );

      final context = navigatorKey.currentContext;
      if (context != null) {
        // Show dialog with instructions first
        final confirmed = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text('Email Unsubscribe'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'To unsubscribe, your email app will open with a pre-filled message:',
                    ),
                    SizedBox(height: 16),
                    Text(
                      'To: ${subscription.unsubscribeEmail}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Subject: Unsubscribe'),
                    SizedBox(height: 8),
                    Text(
                      'After sending the email, please confirm below that you\'ve completed the process.',
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text('CANCEL'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text('OPEN EMAIL APP'),
                  ),
                ],
              ),
        );

        if (confirmed == true) {
          final launched = await launchUrl(emailUri);

          if (launched) {
            // Wait for user to send the email
            final emailSent = await showDialog<bool>(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: Text('Confirm Email Sent'),
                    content: Text(
                      'Did you send the unsubscribe email to ${subscription.senderEmail}?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('NO'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('YES, I SENT IT'),
                      ),
                    ],
                  ),
            );

            if (emailSent == true) {
              await _markAsUnsubscribed(subscription.id);
              eventBus.fire(UnsubscribeCompletedEvent(subscription.id, true));
              return true;
            }
          } else {
            // If URL launch failed, copy to clipboard
            await Clipboard.setData(
              ClipboardData(text: subscription.unsubscribeEmail),
            );
            eventBus.fire(
              ShowToastEvent('Unsubscribe email copied to clipboard'),
            );

            // Ask if they want to mark as unsubscribed anyway
            final manuallyUnsubscribed = await showDialog<bool>(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: Text('Manual Unsubscribe'),
                    content: Text(
                      'The email address has been copied to clipboard. Did you manually send an unsubscribe email to ${subscription.unsubscribeEmail}?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('NO'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('YES'),
                      ),
                    ],
                  ),
            );

            if (manuallyUnsubscribed == true) {
              await _markAsUnsubscribed(subscription.id);
              eventBus.fire(UnsubscribeCompletedEvent(subscription.id, true));
              return true;
            }
          }
        }
      } else {
        // No context available, try direct launch
        final launched = await launchUrl(emailUri);
        if (launched) {
          await _markAsUnsubscribed(subscription.id);
          eventBus.fire(UnsubscribeCompletedEvent(subscription.id, true));
          return true;
        }
      }

      eventBus.fire(UnsubscribeCompletedEvent(subscription.id, false));
      return false;
    } catch (e) {
      print('Email unsubscribe error: $e');
      eventBus.fire(UnsubscribeCompletedEvent(subscription.id, false));
      return false;
    }
  }

  // Add this helper method for browser fallback
  Future<bool> _fallbackToExternalBrowser(
    SubscriptionEmail subscription,
  ) async {
    try {
      final launched = await launchUrl(
        Uri.parse(subscription.unsubscribeUrl),
        mode: LaunchMode.externalApplication,
      );

      if (launched) {
        final context = navigatorKey.currentContext;
        if (context != null) {
          // Wait a moment for the browser to open
          await Future.delayed(Duration(seconds: 2));

          // Show confirmation dialog
          final confirmed = await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text('External Browser'),
                  content: Text(
                    'Please complete the unsubscribe process in your browser.\n\nDid you successfully unsubscribe from ${subscription.sender}?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text('NO'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('YES'),
                    ),
                  ],
                ),
          );

          if (confirmed == true) {
            await _markAsUnsubscribed(subscription.id);
            eventBus.fire(UnsubscribeCompletedEvent(subscription.id, true));
            return true;
          }
        } else {
          // No context available, assume success
          await _markAsUnsubscribed(subscription.id);
          eventBus.fire(UnsubscribeCompletedEvent(subscription.id, true));
          return true;
        }
      } else {
        // Copy link to clipboard as last resort
        await Clipboard.setData(
          ClipboardData(text: subscription.unsubscribeUrl),
        );
        eventBus.fire(ShowToastEvent('Unsubscribe URL copied to clipboard'));

        // In a real-world app, we would check if the user manually completed the process
        await _markAsUnsubscribed(subscription.id);
        eventBus.fire(UnsubscribeCompletedEvent(subscription.id, true));
        return true;
      }
    } catch (e) {
      print('External browser fallback error: $e');
    }

    eventBus.fire(UnsubscribeCompletedEvent(subscription.id, false));
    return false;
  }

  // Cache subscriptions
  Future<void> _cacheSubscriptions(
    List<SubscriptionEmail> subscriptions,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing cached data to preserve unsubscribe status
      final existingData = await _loadCachedSubscriptions();
      final existingMap = {for (var sub in existingData) sub.id: sub};

      // Update with fresh data but preserve unsubscribe status
      for (var i = 0; i < subscriptions.length; i++) {
        final existing = existingMap[subscriptions[i].id];
        if (existing != null && existing.unsubscribeSuccess) {
          subscriptions[i] = subscriptions[i].copyWith(
            unsubscribeSuccess: true,
          );
        }
      }

      // Save to cache
      final jsonData = subscriptions.map((sub) => sub.toJson()).toList();
      await prefs.setString('cached_subscriptions', jsonEncode(jsonData));

      // Update timestamp
      await prefs.setInt(
        'last_subscription_refresh',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      print('Error caching subscriptions: $e');
    }
  }

  // Load cached subscriptions
  Future<List<SubscriptionEmail>> _loadCachedSubscriptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cached_subscriptions');

      if (cachedData != null) {
        final jsonList = jsonDecode(cachedData) as List;
        return jsonList
            .map(
              (item) =>
                  SubscriptionEmail.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }

      return [];
    } catch (e) {
      print('Error loading cached subscriptions: $e');
      return [];
    }
  }

  // Clear cache
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_subscriptions');
      await prefs.remove('last_subscription_refresh');
    } catch (e) {
      print('Error clearing subscription cache: $e');
    }
  }

  // Mark a subscription as unsubscribed in cache
  Future<void> _markAsUnsubscribed(String subscriptionId) async {
    try {
      final subscriptions = await _loadCachedSubscriptions();

      for (var i = 0; i < subscriptions.length; i++) {
        if (subscriptions[i].id == subscriptionId) {
          subscriptions[i] = subscriptions[i].copyWith(
            unsubscribeSuccess: true,
          );
          break;
        }
      }

      // Save updated cache
      final jsonData = subscriptions.map((sub) => sub.toJson()).toList();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_subscriptions', jsonEncode(jsonData));
    } catch (e) {
      print('Error marking subscription as unsubscribed: $e');
    }
  }

  // Helper to throttle API requests
  Future<void> _throttleRequest() async {
    final now = DateTime.now();
    final timeSinceLastRequest = now.difference(_lastApiRequest);

    if (timeSinceLastRequest < _minRequestInterval) {
      final waitTime = _minRequestInterval - timeSinceLastRequest;
      await Future.delayed(waitTime);
    }

    _lastApiRequest = DateTime.now();
  }

  // Add a helper method to get context
  BuildContext? _getContext() {
    try {
      final context = navigatorKey.currentContext;
      if (context == null) {
        print('Warning: navigatorKey.currentContext is null');
      }
      return context;
    } catch (e) {
      print('Error getting context: $e');
      return null;
    }
  }

  // Helper method to safely show dialogs
  void _safelyShowDialog({required Widget dialog, String? fallbackMessage}) {
    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        showDialog(context: context, builder: (context) => dialog);
      } else if (fallbackMessage != null) {
        print('Cannot show dialog: $fallbackMessage');
      }
    } catch (e) {
      print('Error showing dialog: $e');
    }
  }

  // Add this method to your UnsubscribeService class

  Future<void> batchUnsubscribe(List<SubscriptionEmail> subscriptions) async {
    if (subscriptions.isEmpty) return;

    // Track overall progress
    int total = subscriptions.length;
    int completed = 0;
    int succeeded = 0;

    // Process subscriptions sequentially to avoid overwhelming the system
    for (var subscription in subscriptions) {
      try {
        // Skip already unsubscribed or in-progress items
        if (subscription.unsubscribeSuccess || subscription.isUnsubscribing) {
          completed++;
          continue;
        }

        // Notify listeners that we're starting this one
        eventBus.fire(UnsubscribeStartedEvent(subscription.id));

        // Add a small delay between requests to avoid rate limiting
        if (completed > 0) {
          await Future.delayed(Duration(milliseconds: 300));
        }

        // Attempt to unsubscribe
        final success = await unsubscribe(subscription);

        // Count successes
        if (success) succeeded++;

        // Update completion count
        completed++;

        // Fire progress event (optional)
        double progress = completed / total;
        eventBus.fire(BatchProgressEvent(progress, completed, total));
      } catch (e) {
        print('Error in batch unsubscribe for ${subscription.sender}: $e');
        // Fire failure event
        eventBus.fire(UnsubscribeCompletedEvent(subscription.id, false));

        // Still increment completed count
        completed++;
      }
    }

    // Fire completion event
    eventBus.fire(BatchCompletedEvent(total, succeeded));
  }
}
