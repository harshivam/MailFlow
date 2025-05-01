import 'package:mail_merge/features/email/services/email_service.dart';
import 'package:mail_merge/features/email/services/providers/imap_email_service.dart';
import 'package:mail_merge/user/models/email_account.dart';
import 'package:mail_merge/user/repository/account_repository.dart';
import 'package:mail_merge/features/attachments_hub/models/attachment.dart';

class UnifiedEmailService {
  final AccountRepository _accountRepository = AccountRepository();

  // Service cache to avoid recreating services
  final Map<String, dynamic> _serviceCache = {};

  Future<List<Map<String, dynamic>>> fetchUnifiedEmails({
    int maxResults = 30,
    String? pageToken, // not used directly but kept for API consistency
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

  Future<List<EmailAttachment>> fetchAllAttachments() async {
    List<EmailAttachment> allAttachments = [];

    try {
      // Get all emails first
      final emails = await fetchUnifiedEmails(maxResults: 100);

      // For each email, check if it has attachments
      for (var email in emails) {
        // We need to fetch the full message details to get attachment info
        final service = await _getServiceForAccount(
          await _accountRepository.getAccountById(email['accountId']),
        );

        // This is the key improvement - only fetch attachment details on demand
        if (service is EmailService) {
          // Get attachments for this email
          final attachments = await service.fetchAttachmentsForEmail(email);

          // Convert to EmailAttachment objects
          for (var attachment in attachments) {
            allAttachments.add(
              EmailAttachment(
                id: attachment['id'] ?? '',
                name: attachment['filename'] ?? 'Unknown',
                contentType:
                    attachment['mimeType'] ?? 'application/octet-stream',
                size: attachment['size'] ?? 0,
                downloadUrl: attachment['downloadUrl'] ?? '',
                emailId: email['id'] ?? '',
                emailSubject: email['message'] ?? '',
                senderName: email['name'] ?? '',
                senderEmail: email['from'] ?? '',
                date: email['_dateTime'] ?? DateTime.now(),
                accountId: email['accountId'] ?? '',
              ),
            );
          }
        }
      }

      // Sort by date, newest first
      allAttachments.sort((a, b) => b.date.compareTo(a.date));

      return allAttachments;
    } catch (e) {
      print('Error fetching attachments: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _extractAttachments(
    Map<String, dynamic> message,
    String accountId,
  ) async {
    List<Map<String, dynamic>> attachments = [];

    // Check for message parts (where attachments live in Gmail API)
    if (message['payload'] != null && message['payload']['parts'] != null) {
      var parts = message['payload']['parts'] as List;
      for (var part in parts) {
        // Parts with filename and attachmentId are attachments
        if (part['filename'] != null &&
            part['filename'].toString().isNotEmpty &&
            part['body'] != null &&
            part['body']['attachmentId'] != null) {
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
    }

    return attachments;
  }
}
