import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mail_merge/features/email/services/email_service.dart';
import 'package:mail_merge/features/email/services/providers/imap_email_service.dart';
import 'package:mail_merge/features/email/services/unified_email_service.dart';
import 'package:mail_merge/user/models/email_account.dart';
import 'package:mail_merge/user/repository/account_repository.dart';
import 'package:mail_merge/features/attachments_hub/models/attachment.dart';

class UnifiedEmailService {
  final AccountRepository _accountRepository = AccountRepository();

  // Service cache to avoid recreating services
  final Map<String, dynamic> _serviceCache = {};

  // Add these fields at the top of UnifiedEmailService class
  final Map<String, DateTime> _lastRequestTimes = {};
  final _minTimeBetweenRequests = const Duration(milliseconds: 500);
  final _maxEmailsToProcess = 10; // Limit to 10 emails to avoid rate limits

  Future<List<Map<String, dynamic>>> fetchUnifiedEmails({
    int maxResults = 30,
    String? pageToken,
    required bool
    onlyWithAttachments, // not used directly but kept for API consistency
  }) async {
    // Get all accounts
    final accounts = await _accountRepository.getAllAccounts();
    if (accounts.isEmpty) return [];

    // List to hold all emails from all accounts
    List<Map<String, dynamic>> allEmails = [];

    // Fetch emails from all accounts in parallel
    final futures = accounts.map((account) async {
      try {
        final service = await _getServiceForAccount(account);
        final emails = await _fetchFromService(service, account, maxResults);

        // Tag emails with account info and normalize dates
        return emails.map((email) {
          email['accountId'] = account.id;
          email['accountName'] = account.displayName;
          email['provider'] = account.provider.displayName;

          // Consistent date normalization for proper sorting
          try {
            if (email['time'] != null && email['time'].isNotEmpty) {
              // Handle different date formats by converting to DateTime
              DateTime parsedDate;
              try {
                parsedDate = DateTime.parse(email['time']);
              } catch (_) {
                // Handle RFC 822/2822 date format that Gmail often uses
                final regexPattern =
                    r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{4})';
                final match = RegExp(
                  regexPattern,
                  caseSensitive: false,
                ).firstMatch(email['time']);

                if (match != null) {
                  final day = int.parse(match.group(1)!);
                  final monthStr = match.group(2)!;
                  final year = int.parse(match.group(3)!);

                  final months = {
                    'Jan': 1,
                    'Feb': 2,
                    'Mar': 3,
                    'Apr': 4,
                    'May': 5,
                    'Jun': 6,
                    'Jul': 7,
                    'Aug': 8,
                    'Sep': 9,
                    'Oct': 10,
                    'Nov': 11,
                    'Dec': 12,
                  };

                  final month = months[monthStr] ?? 1;
                  parsedDate = DateTime(year, month, day);
                } else {
                  // If all parsing fails, use a random old date with slight variation
                  // to avoid having multiple emails with exactly the same timestamp
                  parsedDate = DateTime(
                    2000,
                    1,
                    1,
                  ).add(Duration(minutes: allEmails.length));
                }
              }
              email['_dateTime'] = parsedDate;
            } else {
              // Use current time with an offset to maintain ordering when no date is available
              email['_dateTime'] = DateTime.now().subtract(
                Duration(minutes: allEmails.length),
              );
            }
          } catch (e) {
            print('Error parsing date: ${email['time']} - $e');
            // Fallback to current time with a slight variation
            email['_dateTime'] = DateTime.now().subtract(
              Duration(minutes: allEmails.length),
            );
          }

          return email;
        }).toList();
      } catch (e) {
        print('Error fetching from account ${account.email}: $e');
        return <Map<String, dynamic>>[];
      }
    });

    // Wait for all fetches to complete
    final results = await Future.wait(futures);

    // Combine all emails into a single flat list
    for (var emailList in results) {
      allEmails.addAll(emailList);
    }

    // Sort emails by date using the normalized _dateTime field
    allEmails.sort((b, a) {
      final dateA = a['_dateTime'] as DateTime;
      final dateB = b['_dateTime'] as DateTime;
      // You can change dateA.compareTo(dateB) to dateB.compareTo(dateA) to reverse order
      return dateA.compareTo(dateB);
    });

    return allEmails;
  }

  Future<dynamic> _getServiceForAccount(EmailAccount account) async {
    // Return cached service if available
    if (_serviceCache.containsKey(account.id)) {
      return _serviceCache[account.id];
    }

    // Create new service based on provider
    final service = await _createServiceForAccount(account);
    _serviceCache[account.id] = service;
    return service;
  }

  Future<dynamic> _createServiceForAccount(EmailAccount account) async {
    switch (account.provider) {
      case AccountProvider.gmail:
        return EmailService(account.accessToken);
      case AccountProvider.outlook:
      case AccountProvider.rediffmail:
        return ImapEmailService(account);
    }
  }

  Future<List<Map<String, dynamic>>> _fetchFromService(
    dynamic service,
    EmailAccount account,
    int maxResults,
  ) async {
    try {
      if (service is EmailService) {
        final result = await service.fetchEmails(maxResults: maxResults);
        return result.emails;
      } else if (service is ImapEmailService) {
        return await service.fetchEmails(maxResults: maxResults);
      }
      return [];
    } catch (e) {
      print('Error fetching emails for ${account.email}: $e');
      return [];
    }
  }

  // Method to fetch emails for VIP contacts from all accounts
  Future<Map<String, List<Map<String, dynamic>>>> fetchVipEmailsByContact(
    List<String> vipEmails, {
    int maxResults = 10,
  }) async {
    final accounts = await _accountRepository.getAllAccounts();
    if (accounts.isEmpty) return {};

    Map<String, List<Map<String, dynamic>>> emailsByContact = {};

    // Initialize empty lists for each contact
    for (var email in vipEmails) {
      emailsByContact[email.toLowerCase()] = [];
    }

    // Fetch emails for all VIP contacts in parallel across all accounts
    for (var account in accounts) {
      try {
        final service = await _getServiceForAccount(account);

        // For each VIP contact, fetch their emails from this account
        for (var contactEmail in vipEmails) {
          var emails = await _fetchVipEmailsForContact(
            service,
            account,
            contactEmail,
            maxResults,
          );

          // Add account info to emails
          emails =
              emails.map((email) {
                email['accountId'] = account.id;
                email['accountName'] = account.displayName;
                email['provider'] = account.provider.displayName;
                return email;
              }).toList();

          // Add emails to the contact's list
          emailsByContact[contactEmail.toLowerCase()]?.addAll(emails);
        }
      } catch (e) {
        print('Error fetching VIP emails from ${account.email}: $e');
      }
    }

    // Sort each contact's emails by date
    emailsByContact.forEach((contactEmail, emails) {
      emails.sort((a, b) {
        final dateA = DateTime.tryParse(a['time'] ?? '') ?? DateTime(1970);
        final dateB = DateTime.tryParse(b['time'] ?? '') ?? DateTime(1970);
        return dateA.compareTo(dateB); // Changed from dateB.compareTo(dateA)
      });
    });

    return emailsByContact;
  }

  Future<List<Map<String, dynamic>>> _fetchVipEmailsForContact(
    dynamic service,
    EmailAccount account,
    String contactEmail,
    int maxResults,
  ) async {
    try {
      if (service is EmailService) {
        // Gmail uses query parameter
        final query = 'from:${contactEmail.toLowerCase()}';
        return await service.fetchEmailsWithQuery(
          query,
          maxResults: maxResults,
        );
      } else if (service is ImapEmailService) {
        // IMAP would need a different approach - simpler filtering
        final allEmails = await service.fetchEmails(maxResults: 30);
        return allEmails
            .where(
              (email) => email["from"].toString().toLowerCase().contains(
                contactEmail.toLowerCase(),
              ),
            )
            .take(maxResults)
            .toList();
      }
      return [];
    } catch (e) {
      print(
        'Error fetching VIP emails for $contactEmail from ${account.email}: $e',
      );
      return [];
    }
  }

  // Add this helper method
  Future<void> _throttleRequest(String key) async {
    final now = DateTime.now();
    final lastRequest = _lastRequestTimes[key];

    if (lastRequest != null) {
      final elapsed = now.difference(lastRequest);
      if (elapsed < _minTimeBetweenRequests) {
        final waitTime = _minTimeBetweenRequests - elapsed;
        print(
          'Throttling request for $key: waiting ${waitTime.inMilliseconds}ms',
        );
        await Future.delayed(waitTime);
      }
    }

    _lastRequestTimes[key] = DateTime.now();
  }

  // Replace the fetchAllAttachments method with this version
  Future<List<EmailAttachment>> fetchAllAttachments() async {
    List<EmailAttachment> allAttachments = [];
    int retryCount = 0;
    final maxRetries = 3;
    bool shouldRetry = true;

    while (shouldRetry && retryCount <= maxRetries) {
      try {
        await _throttleRequest('fetchEmails');

        // Get a smaller set of emails to reduce API calls
        final emails = await fetchUnifiedEmails(
          maxResults: 5,
          onlyWithAttachments: true,
        );

        print('Found ${emails.length} emails that might have attachments');

        // Process each email with rate limiting
        for (int i = 0; i < emails.length; i++) {
          // Added pause between processing each email
          if (i > 0) {
            await Future.delayed(Duration(seconds: 1));
          }

          final email = emails[i];
          final accountId = email['accountId'];
          if (accountId == null) continue;

          try {
            // Get the account info
            await _throttleRequest('getAccount_$accountId');
            final account = await _accountRepository.getAccountById(accountId);

            // Get the email service for this account
            final service = await _getServiceForAccount(account);

            // Process Gmail attachments
            if (service is EmailService) {
              // Get message ID
              final messageId = email['id'];
              if (messageId == null) continue;

              // Throttle before fetching message
              await _throttleRequest('email_$messageId');

              // Get the full message details including parts
              final fullMessage = await service.getMessage(messageId);
              if (fullMessage == null) {
                print('Could not get message details for $messageId');
                continue;
              }

              // Extract attachments from the message
              final attachments = await _extractAttachments(
                fullMessage,
                accountId,
              );

              // Create EmailAttachment objects for each attachment
              for (var attachment in attachments) {
                allAttachments.add(
                  EmailAttachment(
                    id: attachment['id'] ?? '',
                    name: attachment['filename'] ?? 'Unknown',
                    contentType:
                        attachment['mimeType'] ?? 'application/octet-stream',
                    size: attachment['size'] ?? 0,
                    downloadUrl: attachment['downloadUrl'] ?? '',
                    emailId: messageId,
                    emailSubject: email['message'] ?? '',
                    senderName: email['name'] ?? '',
                    senderEmail: email['from'] ?? '',
                    date: email['_dateTime'] ?? DateTime.now(),
                    accountId: accountId,
                  ),
                );
              }
            }
          } catch (e) {
            print('Error processing email ${email['id']}: $e');
            // Continue to next email - don't rethrow
          }
        }

        // If we reach here without exceptions, no need to retry
        shouldRetry = false;

        // Sort by date, newest first
        allAttachments.sort((a, b) => b.date.compareTo(a.date));

        print('Found ${allAttachments.length} attachments total');
      } catch (e) {
        if (e.toString().contains('429')) {
          print('Rate limited (429) while fetching emails. Backing off.');
          if (retryCount < maxRetries) {
            retryCount++;
            await Future.delayed(Duration(seconds: 5 * retryCount));
            // Continue to the next iteration to retry
            continue;
          }
        }
        // If not a 429 error or we've exceeded retries, return empty list
        print('Error fetching attachments: $e');
        return [];
      }
    }

    return allAttachments;
  }

  // In UnifiedEmailService class:
  Future<List<EmailAttachment>> fetchPaginatedAttachments({
    int page = 0,
    int pageSize = 3,
  }) async {
    // Only fetch 3 emails per page to avoid rate limits
    final emails = await fetchUnifiedEmails(
      maxResults: 5,
      onlyWithAttachments: true,
    );

    // Process emails with proper delays between requests
    // TODO: Implement pagination logic
    return []; // Return empty list for now
  }

  // Update this method to add more debugging
  Future<List<Map<String, dynamic>>> _extractAttachments(
    Map<String, dynamic> message,
    String accountId,
  ) async {
    List<Map<String, dynamic>> attachments = [];

    try {
      print('Extracting attachments from message ID: ${message['id']}');

      // Check if message payload exists
      if (message['payload'] == null) {
        print('Message payload is null');
        return attachments;
      }

      // Check if parts exist
      if (message['payload']['parts'] == null) {
        print('No parts found in message ${message['id']}');
        return attachments;
      }

      var parts = message['payload']['parts'] as List;
      print('Found ${parts.length} parts in message ${message['id']}');

      for (var part in parts) {
        // Parts with filename and attachmentId are attachments
        if (part['filename'] != null &&
            part['filename'].toString().isNotEmpty &&
            part['body'] != null &&
            part['body']['attachmentId'] != null) {
          print(
            'Found attachment: ${part['filename']} in message ${message['id']}',
          );
          print('Found attachment of type: ${part['mimeType']} with filename: ${part['filename']}');
          attachments.add({
            'id': part['body']['attachmentId'],
            'filename': part['filename'],
            'mimeType': part['mimeType'] ?? 'application/octet-stream',
            'size': part['body']['size'] ?? 0,
            'downloadUrl':
                'https://gmail.googleapis.com/gmail/v1/users/me/messages/${message['id']}/attachments/${part['body']['attachmentId']}',
          });
        }
      }

      print(
        'Extracted ${attachments.length} attachments from message ${message['id']}',
      );
      return attachments;
    } catch (e) {
      print('Error extracting attachments from message ${message['id']}: $e');
      return attachments;
    }
  }
}
