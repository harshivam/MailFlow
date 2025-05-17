import 'dart:math';
import 'package:mail_merge/features/email/services/email_service.dart';
import 'package:mail_merge/features/email/services/providers/imap_email_service.dart';
import 'package:mail_merge/user/authentication/outlook_email_service.dart';
import 'package:mail_merge/user/models/email_account.dart';
import 'package:mail_merge/user/repository/account_repository.dart';
import 'package:mail_merge/features/attachments_hub/models/attachment.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    String? query, // Add this parameter
  }) async {
    // Get all accounts
    final accounts = await _accountRepository.getAllAccounts();
    if (accounts.isEmpty) return [];

    // List to hold all emails from all accounts
    List<Map<String, dynamic>> allEmails = [];

    // CHANGE #1: Pre-fetch all emails before processing
    final allRawEmails = <Map<String, dynamic>>[];

    // Fetch emails from all accounts
    for (var account in accounts) {
      try {
        final service = await _getServiceForAccount(account);
        final emails = await _fetchFromService(service, account, maxResults);

        // Add to raw email list with account info
        for (var email in emails) {
          email['accountId'] = account.id;
          email['accountName'] = account.displayName;
          email['provider'] = account.provider.displayName;
          allRawEmails.add(email);
        }
      } catch (e) {
        print('Error fetching from account ${account.email}: $e');
      }
    }

    // CHANGE #2: Process all emails consistently
    for (var email in allRawEmails) {
      try {
        // Process date consistently with better normalization
        DateTime emailDate;

        if (email['time'] != null && email['time'].toString().isNotEmpty) {
          try {
            // Try standard formats first
            emailDate = DateTime.parse(email['time']);

            // IMPORTANT: Normalize to minute precision to avoid microsecond differences
            // This ensures emails from different providers with the same "human time"
            // are treated as equivalent for sorting purposes
            emailDate = DateTime(
              emailDate.year,
              emailDate.month,
              emailDate.day,
              emailDate.hour,
              emailDate.minute,
            );
          } catch (_) {
            try {
              // Handle Gmail's RFC format
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
                emailDate = DateTime(year, month, day);
              } else {
                // For Outlook dates
                final outlookRegex = r'(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})';
                final outlookMatch = RegExp(
                  outlookRegex,
                ).firstMatch(email['time']);

                if (outlookMatch != null) {
                  emailDate = DateTime.parse(outlookMatch.group(1)!);
                } else {
                  // Last resort
                  emailDate = DateTime.now().subtract(
                    Duration(minutes: allEmails.length),
                  );
                }
              }
            } catch (e) {
              print('Error parsing date: ${email['time']} - $e');
              emailDate = DateTime.now().subtract(
                Duration(minutes: allEmails.length),
              );
            }
          }
        } else {
          // No date available
          emailDate = DateTime.now().subtract(
            Duration(minutes: allEmails.length),
          );
        }

        // Store the processed date
        email['_dateTime'] = emailDate;
        allEmails.add(email);
      } catch (e) {
        print('Error processing email: $e');
      }
    }

    // CHANGE #3: Complete rewrite of the sorting algorithm to ensure proper interleaving
    print('Implementing truly randomized provider distribution strategy...');

    // First, sort all emails by date
    allEmails.sort((a, b) {
      final dateA = a['_dateTime'] as DateTime;
      final dateB = b['_dateTime'] as DateTime;
      return dateB.compareTo(dateA); // Newest first
    });

    // Step 1: Split emails by provider
    Map<String, List<Map<String, dynamic>>> emailsByProvider = {};
    for (var email in allEmails) {
      final provider = email['provider'] as String;
      if (!emailsByProvider.containsKey(provider)) {
        emailsByProvider[provider] = [];
      }
      emailsByProvider[provider]!.add(email);
    }

    // Step 2: Find the maximum number of time slices needed
    const timeSliceMinutes = 15; // 15-minute time slices
    int maxTimeSlices = 0;

    emailsByProvider.forEach((provider, emails) {
      if (emails.isEmpty) return;

      final newestDate = emails.first['_dateTime'] as DateTime;
      final oldestDate = emails.last['_dateTime'] as DateTime;

      final timeDiffMinutes = newestDate.difference(oldestDate).inMinutes;
      final timeSlices = (timeDiffMinutes / timeSliceMinutes).ceil();

      if (timeSlices > maxTimeSlices) {
        maxTimeSlices = timeSlices;
      }
    });

    maxTimeSlices = maxTimeSlices == 0 ? 1 : maxTimeSlices;
    print('Using $maxTimeSlices time slices for interleaving');

    // Step 3: Create time-slice buckets for each provider
    Map<String, List<List<Map<String, dynamic>>>> providerTimeSlices = {};

    emailsByProvider.forEach((provider, emails) {
      if (emails.isEmpty) return;

      final newestDate = emails.first['_dateTime'] as DateTime;
      final slicedEmails = List<List<Map<String, dynamic>>>.generate(
        maxTimeSlices,
        (_) => <Map<String, dynamic>>[],
      );

      // Distribute emails into time slices
      for (var email in emails) {
        final date = email['_dateTime'] as DateTime;
        final minutesSinceNewest = newestDate.difference(date).inMinutes;
        final sliceIndex = (minutesSinceNewest / timeSliceMinutes).floor();

        // Cap at the maximum index
        final actualIndex =
            sliceIndex < maxTimeSlices ? sliceIndex : maxTimeSlices - 1;
        slicedEmails[actualIndex].add(email);
      }

      providerTimeSlices[provider] = slicedEmails;
    });

    // Step 4: Interleave emails from each provider's time slices
    List<Map<String, dynamic>> interleavedEmails = [];

    // Process each time slice
    for (int sliceIndex = 0; sliceIndex < maxTimeSlices; sliceIndex++) {
      // Collect all providers' emails for this time slice
      List<Map<String, dynamic>> sliceEmails = [];

      emailsByProvider.keys.forEach((provider) {
        final timeSlices = providerTimeSlices[provider];
        if (timeSlices != null && sliceIndex < timeSlices.length) {
          sliceEmails.addAll(timeSlices[sliceIndex]);
        }
      });

      // Sort emails within this slice by date
      sliceEmails.sort((a, b) {
        final dateA = a['_dateTime'] as DateTime;
        final dateB = b['_dateTime'] as DateTime;
        return dateB.compareTo(dateA); // Newest first
      });

      // Now perfect-shuffle the providers within this sorted slice
      if (sliceEmails.length > 1) {
        final Map<String, List<Map<String, dynamic>>> groupedByProvider = {};

        // Group by provider
        for (var email in sliceEmails) {
          final provider = email['provider'] as String;
          if (!groupedByProvider.containsKey(provider)) {
            groupedByProvider[provider] = [];
          }
          groupedByProvider[provider]!.add(email);
        }

        // Clear the slice list
        sliceEmails = [];

        // Interleave the providers in this time slice
        bool hasMoreEmails = true;
        while (hasMoreEmails) {
          hasMoreEmails = false;

          for (final provider in groupedByProvider.keys) {
            final emails = groupedByProvider[provider]!;
            if (emails.isNotEmpty) {
              sliceEmails.add(emails.removeAt(0));
              hasMoreEmails = true;
            }
          }
        }
      }

      // Add this slice's emails to the final list
      interleavedEmails.addAll(sliceEmails);
    }

    // Keep only the first maxResults emails
    if (interleavedEmails.length > maxResults) {
      interleavedEmails = interleavedEmails.sublist(0, maxResults);
    }

    print('Final interleaved email count: ${interleavedEmails.length}');
    print(
      'Provider distribution: ' +
          emailsByProvider.entries
              .map((e) => '${e.key}: ${e.value.length}')
              .join(', '),
    );

    return interleavedEmails;
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
        return OutlookEmailService(account);
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
      } else if (service is OutlookEmailService) {
        return await service.fetchEmails(maxResults: maxResults);
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
      } else if (service is OutlookEmailService) {
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

  // Optimize the fetchAllAttachments method

  Future<List<EmailAttachment>> fetchAllAttachments({
    String? accountId, // Add this parameter
    int maxEmails = 10, // Add this parameter
    int maxAttachments = 30, // Add this parameter
  }) async {
    List<EmailAttachment> allAttachments = [];
    int retryCount = 0;
    final maxRetries = 3;

    try {
      // Optimize email fetching - use batch API when possible
      // Add timestamp to only fetch newer emails
      final lastFetchTime = await _getLastAttachmentFetchTime();
      String query = '';

      if (lastFetchTime != null) {
        // Only fetch emails since last fetch - HUGE optimization
        final dateStr = _formatDateForQuery(lastFetchTime);
        query = 'after:$dateStr has:attachment';
      } else {
        query = 'has:attachment';
      }

      // Use query parameter for more efficient fetching
      final emails = await fetchUnifiedEmails(
        maxResults: maxEmails,
        onlyWithAttachments: true,
        query: query,
      );

      print('Found ${emails.length} emails that might have attachments');

      // Filter for specific account if needed
      final filteredEmails =
          accountId != null
              ? emails
                  .where((email) => email['accountId'] == accountId)
                  .toList()
              : emails;

      // Process emails in smaller batches to stay within rate limits
      // but faster than complete sequential processing
      const batchSize = 3; // Process 3 emails at a time
      int processedAttachments = 0;

      for (int i = 0; i < filteredEmails.length; i += batchSize) {
        // Process a batch of emails in parallel with controlled concurrency
        final batch = filteredEmails.skip(i).take(batchSize).toList();

        // Process each batch with controlled parallelism
        final results = await Future.wait(
          batch.map((email) async {
            if (processedAttachments >= maxAttachments) return [];

            try {
              final emailAccountId = email['accountId'];
              if (emailAccountId == null) return [];

              final account = await _accountRepository.getAccountById(
                emailAccountId,
              );
              final service = await _getServiceForAccount(account);

              // For Gmail accounts, use optimized attachment fetching
              if (service is EmailService) {
                final messageId = email['id'];
                if (messageId == null) return [];

                // Use message cache to avoid refetching
                final cacheKey = 'message_$messageId';
                Map<String, dynamic>? fullMessage;

                if (_messageCache.containsKey(cacheKey)) {
                  fullMessage = _messageCache[cacheKey];
                } else {
                  // Get full message with attachments
                  fullMessage = await service.getMessage(messageId);
                  if (fullMessage != null) {
                    _messageCache[cacheKey] = fullMessage;
                  }
                }

                if (fullMessage == null) return [];

                // Extract attachments more efficiently
                final attachmentsList = await _extractAttachments(
                  fullMessage,
                  emailAccountId,
                );

                // Map to EmailAttachment objects
                return attachmentsList.map((attachment) {
                  return EmailAttachment(
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
                    accountId: emailAccountId,
                  );
                }).toList();
              } else if (service is OutlookEmailService) {
                final messageId = email['id'];
                if (messageId == null) return [];

                // Get Outlook attachments
                final attachmentsList = await service.getAttachments(messageId);

                // Map to EmailAttachment objects
                return attachmentsList.map((attachment) {
                  return EmailAttachment(
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
                    accountId: emailAccountId,
                  );
                }).toList();
              }

              return [];
            } catch (e) {
              print('Error processing email: $e');
              return [];
            }
          }),
          eagerError: false,
        );

        // Add all attachments from this batch
        for (var attachments in results) {
          if (processedAttachments + attachments.length > maxAttachments) {
            // Take only what we need to reach maxAttachments
            allAttachments.addAll(
              attachments
                  .take(maxAttachments - processedAttachments)
                  .cast<EmailAttachment>(),
            );
            processedAttachments = maxAttachments;
            break;
          } else {
            allAttachments.addAll(attachments as Iterable<EmailAttachment>);
            processedAttachments += attachments.length;
          }
        }

        if (processedAttachments >= maxAttachments) break;

        // Only wait between batches, not between each email
        await Future.delayed(Duration(milliseconds: 500));
      }

      // Save the current time as last fetch time
      await _setLastAttachmentFetchTime(DateTime.now());

      // Sort by date (newest first)
      allAttachments.sort((a, b) => b.date.compareTo(a.date));

      print(
        'Optimized fetch complete with ${allAttachments.length} attachments',
      );
      return allAttachments;
    } catch (e) {
      print('Error fetching attachments: $e');
      return [];
    }
  }

  // Helper method to format date for Gmail query
  String _formatDateForQuery(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }

  // Helper methods for last fetch time
  Future<DateTime?> _getLastAttachmentFetchTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('last_attachment_api_fetch');
      if (timestamp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    } catch (e) {
      return null;
    }
  }

  Future<void> _setLastAttachmentFetchTime(DateTime time) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'last_attachment_api_fetch',
        time.millisecondsSinceEpoch,
      );
    } catch (e) {
      print('Error saving last fetch time: $e');
    }
  }

  // Add a message cache to avoid repeated API calls
  final Map<String, Map<String, dynamic>> _messageCache = {};

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
          print(
            'Found attachment of type: ${part['mimeType']} with filename: ${part['filename']}',
          );
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
