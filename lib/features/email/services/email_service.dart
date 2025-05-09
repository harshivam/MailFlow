import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailPageResult {
  final List<Map<String, dynamic>> emails;
  final String? nextPageToken;
  final bool hasMore;

  EmailPageResult({
    required this.emails,
    required this.nextPageToken,
    required this.hasMore,
  });
}

class EmailResult {
  final List<Map<String, dynamic>> emails;
  final String? nextPageToken;
  final bool hasMore;

  EmailResult(this.emails, this.nextPageToken, this.hasMore);
}

class EmailService {
  final String accessToken;

  EmailService(this.accessToken);

  Future<EmailResult> fetchEmails({
    String? pageToken,
    int maxResults = 15,
  }) async {
    if (accessToken.isEmpty) {
      return EmailResult([], null, false);
    }

    try {
      final response = await http.get(
        Uri.parse(
          'https://www.googleapis.com/gmail/v1/users/me/messages?maxResults=$maxResults${pageToken != null ? '&pageToken=$pageToken' : ''}',
        ),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final messages = data['messages'] as List<dynamic>?;
        final nextPageToken = data['nextPageToken'] as String?;

        if (messages == null || messages.isEmpty) {
          return EmailResult([], null, false);
        }

        // Process message details in parallel for faster loading
        final futures = messages.map(
          (message) => _fetchEmailDetails(message['id']),
        );
        final emailDetails = await Future.wait(futures);

        final emailData =
            emailDetails
                .where((detail) => detail != null)
                .cast<Map<String, dynamic>>()
                .toList();

        return EmailResult(emailData, nextPageToken, nextPageToken != null);
      } else {
        print('Error fetching emails: ${response.statusCode}');
        return EmailResult([], null, false);
      }
    } catch (e) {
      print('Error fetching emails: $e');
      return EmailResult([], null, false);
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllEmails({
    int maxResults = 100,
  }) async {
    if (accessToken.isEmpty) {
      return [];
    }

    try {
      List<Map<String, dynamic>> allEmails = [];
      String? pageToken;
      bool hasMore = true;

      // Fetch emails page by page until we have enough or there are no more
      while (hasMore && allEmails.length < maxResults) {
        final result = await fetchEmails(pageToken: pageToken);
        allEmails.addAll(result.emails);

        pageToken = result.nextPageToken;
        hasMore = result.hasMore;

        if (allEmails.length >= maxResults) {
          break;
        }
      }

      return allEmails;
    } catch (e) {
      print('Error fetching all emails: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> _fetchEmailDetails(String messageId) async {
    try {
      final detailResponse = await http.get(
        Uri.parse(
          'https://gmail.googleapis.com/gmail/v1/users/me/messages/$messageId',
        ),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );

      if (detailResponse.statusCode == 200) {
        final emailData = json.decode(detailResponse.body);
        final snippet = emailData['snippet'] ?? '';
        final headers = emailData['payload']['headers'] as List;

        // Extract headers
        String subject = 'No Subject';
        String sender = 'Unknown';
        String from = '';
        String time = '';
        String avatar =
            'https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png';
        String contentType = '';

        for (var header in headers) {
          if (header['name'] == 'Subject') {
            subject = header['value'];
          } else if (header['name'] == 'From') {
            final fullFrom = header['value'];
            sender = fullFrom;

            // Extract email address
            final emailRegex = RegExp(r'<([^>]+)>');
            final match = emailRegex.firstMatch(fullFrom);

            if (match != null && match.groupCount >= 1) {
              from = match.group(1)!;
            } else {
              from = fullFrom;
            }

            // Clean up the display name
            if (sender.contains('<')) {
              sender = sender.split('<')[0].trim();
              if (sender.startsWith('"') && sender.endsWith('"')) {
                sender = sender.substring(1, sender.length - 1);
              }
            }
          } else if (header['name'] == 'Date') {
            time = header['value'];
          } else if (header['name'] == 'Content-Type') {
            contentType = header['value'];
          }
        }

        // Extract email content
        String htmlBody = '';
        String plainTextBody = '';

        try {
          // Extract content recursively from the payload
          final extractedContent = _extractContent(emailData['payload'], []);

          htmlBody = extractedContent['html'] ?? '';
          plainTextBody = extractedContent['plain'] ?? '';

          // If no content was found but there's a direct body
          if (htmlBody.isEmpty &&
              plainTextBody.isEmpty &&
              emailData['payload']['body'] != null &&
              emailData['payload']['body']['data'] != null) {
            final data = emailData['payload']['body']['data'];
            plainTextBody = _decodeBase64String(data);
          }
        } catch (e) {
          print('Error extracting email content: $e');
        }

        // When returning email data, check for attachment metadata only (not content)
        bool hasAttachments = false;
        List<Map<String, dynamic>> attachmentMetadata = [];

        // Check if message has parts that might be attachments
        if (emailData['payload'] != null &&
            emailData['payload']['parts'] != null) {
          final parts = emailData['payload']['parts'] as List;

          for (var part in parts) {
            if (part['filename'] != null &&
                part['filename'].toString().isNotEmpty &&
                part['body'] != null &&
                part['body']['attachmentId'] != null) {
              hasAttachments = true;
              attachmentMetadata.add({
                'id': part['body']['attachmentId'],
                'filename': part['filename'],
                'mimeType': part['mimeType'] ?? 'application/octet-stream',
                'size': part['body']['size'] ?? 0,
                'downloadUrl':
                    'https://gmail.googleapis.com/gmail/v1/users/me/messages/$messageId/attachments/${part['body']['attachmentId']}',
              });
            }
          }
        }

        return {
          "id": messageId,
          "name": sender,
          "from": from,
          "message": subject,
          "snippet": snippet,
          "time": time,
          "avatar": avatar,
          "htmlBody": htmlBody,
          "plainTextBody": plainTextBody,
          "hasAttachments": hasAttachments,
          "attachments":
              attachmentMetadata, // Just metadata, no content download
        };
      }
      return null;
    } catch (e) {
      print('Error fetching email details: $e');
      return null;
    }
  }

  // Add this helper method for decoding base64 email content
  String _decodeBase64String(String data) {
    try {
      // Handle URL-safe Base64 encoding that Gmail uses
      final normalized = data.replaceAll('-', '+').replaceAll('_', '/');

      // Add padding if necessary
      final padLength = (4 - normalized.length % 4) % 4;
      final padded = normalized + ('=' * padLength);

      // First try standard UTF-8 decoding
      try {
        return utf8.decode(base64Decode(padded));
      } catch (e) {
        // If UTF-8 fails, try Latin1 (ISO-8859-1) which is common in emails
        try {
          return latin1.decode(base64Decode(padded));
        } catch (e2) {
          // Last resort: try ASCII and replace non-ASCII characters
          return ascii.decode(base64Decode(padded), allowInvalid: true);
        }
      }
    } catch (e) {
      print('Error decoding base64: $e');
      return '';
    }
  }

  Future<Map<String, dynamic>> _fetchFullMessage(String messageId) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://gmail.googleapis.com/gmail/v1/users/me/messages/$messageId',
        ),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch message: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching message details: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _extractAttachments(
    Map<String, dynamic> message,
    String emailId,
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
                'https://gmail.googleapis.com/gmail/v1/users/me/messages/$emailId/attachments/${part['body']['attachmentId']}',
          });
        }
      }
    }

    return attachments;
  }

  /// Fetches attachments for a specific email only when they're needed
  /// This allows the email list to load much faster
  Future<List<Map<String, dynamic>>> fetchAttachmentsForEmail(
    Map<String, dynamic> email,
  ) async {
    try {
      if (email['attachments'] == null || email['attachments'].isEmpty) {
        final messageId = email['id'];
        if (messageId == null) return [];

        // Fetch the full message with all parts
        final fullMessage = await _fetchFullMessage(messageId);

        // Extract attachments
        List<Map<String, dynamic>> attachments = [];

        // Check for message parts (where attachments live in Gmail API)
        if (fullMessage['payload'] != null &&
            fullMessage['payload']['parts'] != null) {
          var parts = fullMessage['payload']['parts'] as List;
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
                    'https://gmail.googleapis.com/gmail/v1/users/me/messages/$messageId/attachments/${part['body']['attachmentId']}',
              });
            }
          }
        }

        // Update the email object with attachments
        email['attachments'] = attachments;
        email['hasAttachments'] = attachments.isNotEmpty;

        return attachments;
      }
      return email['attachments'] ?? [];
    } catch (e) {
      print('Error fetching attachments for email ${email['id']}: $e');
      return [];
    }
  }

  // Add this method inside the EmailService class
  Future<Map<String, dynamic>?> getMessage(String messageId) async {
    try {
      final url = Uri.parse(
        'https://www.googleapis.com/gmail/v1/users/me/messages/$messageId?format=full',
      );

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        print('Error getting message $messageId: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Exception getting message $messageId: $e');
      return null;
    }
  }

  // Add this method to your EmailService class

  Future<List<Map<String, dynamic>>> fetchEmailsWithQuery(
    String query, {
    int maxResults = 20,
  }) async {
    if (accessToken.isEmpty) {
      return [];
    }

    try {
      // Encode the query parameter properly
      final encodedQuery = Uri.encodeComponent(query);

      final response = await http.get(
        Uri.parse(
          'https://www.googleapis.com/gmail/v1/users/me/messages?maxResults=$maxResults&q=$encodedQuery',
        ),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final messages = data['messages'] as List<dynamic>?;

        if (messages == null || messages.isEmpty) {
          return [];
        }

        // Process message details in parallel for faster loading
        final futures = messages.map(
          (message) => _fetchEmailDetails(message['id']),
        );
        final emailDetails = await Future.wait(futures);

        return emailDetails
            .where((detail) => detail != null)
            .cast<Map<String, dynamic>>()
            .toList();
      } else {
        print('Error fetching emails with query: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error fetching emails with query: $e');
      return [];
    }
  }

  // Add this new recursive content extraction method
  Map<String, String> _extractContent(
    Map<String, dynamic> part,
    List<String> path,
  ) {
    final result = {'html': '', 'plain': ''};

    // Handle different MIME types
    final mimeType = part['mimeType'] ?? '';

    // For text parts that have data
    if (mimeType.startsWith('text/') &&
        part['body'] != null &&
        part['body']['data'] != null) {
      final content = _decodeBase64String(part['body']['data']);

      if (mimeType == 'text/html') {
        result['html'] = content;
      } else if (mimeType == 'text/plain') {
        result['plain'] = content;
      }
    }

    // For multipart messages, recursively extract from each part
    if (mimeType.startsWith('multipart/') && part['parts'] != null) {
      final parts = part['parts'] as List;

      // Process each subpart
      for (var subpart in parts) {
        final newPath = List<String>.from(path)..add(mimeType);
        final subResult = _extractContent(subpart, newPath);

        // Prefer HTML over plain text
        if (subResult['html']!.isNotEmpty && result['html']!.isEmpty) {
          result['html'] = subResult['html']!;
        }

        // Only use plain text if we don't have it yet
        if (subResult['plain']!.isNotEmpty && result['plain']!.isEmpty) {
          result['plain'] = subResult['plain']!;
        }
      }
    }

    // Handle special case of message/rfc822 (forwarded messages)
    if (mimeType == 'message/rfc822' && part['body'] != null) {
      // Message itself might have parts or a body
      if (part['parts'] != null) {
        final newPath = List<String>.from(path)..add('message/rfc822');
        for (var subpart in part['parts'] as List) {
          final subResult = _extractContent(subpart, newPath);
          if (subResult['html']!.isNotEmpty) {
            result['html'] = subResult['html']!;
          }
          if (subResult['plain']!.isNotEmpty) {
            result['plain'] = subResult['plain']!;
          }
        }
      } else if (part['body']['data'] != null) {
        result['plain'] = _decodeBase64String(part['body']['data']);
      }
    }

    return result;
  }
}
