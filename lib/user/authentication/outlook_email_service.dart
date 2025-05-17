import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mail_merge/user/models/email_account.dart';

class OutlookEmailService {
  final EmailAccount account;

  OutlookEmailService(this.account);

  Future<List<Map<String, dynamic>>> fetchEmails({
    String? pageToken,
    int maxResults = 15,
  }) async {
    try {
      final url =
          pageToken ??
          'https://graph.microsoft.com/v1.0/me/messages?\$top=$maxResults&\$orderby=receivedDateTime desc&\$select=id,subject,bodyPreview,receivedDateTime,from,body,hasAttachments';

      print('Fetching Outlook emails from URL: $url'); // Debug log

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${account.accessToken}',
          'Accept': 'application/json',
        },
      );

      print('Outlook API response status: ${response.statusCode}'); // Debug log

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final messages = data['value'] as List;

        print('Retrieved ${messages.length} Outlook messages'); // Debug log

        return messages.map((message) {
          final from = message['from']['emailAddress'];
          return {
            'id': message['id'],
            'name': from['name'] ?? 'Unknown',
            'from': from['address'] ?? '',
            'message': message['subject'] ?? 'No Subject',
            'snippet': message['bodyPreview'] ?? '',
            'time': message['receivedDateTime'] ?? '',
            'avatar': 'https://via.placeholder.com/150',
            'htmlBody': message['body']['content'] ?? '',
            'contentType': message['body']['contentType'] ?? 'text',
            'hasAttachments': message['hasAttachments'] ?? false,
            'provider': "Outlook",
            'accountId': account.id,
            'accountName': account.displayName,
          };
        }).toList();
      } else {
        print('Error response: ${response.body}'); // Debug log
        return [];
      }
    } catch (e) {
      print('Error fetching Outlook emails: $e'); // Debug log
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchEmailsWithQuery(
    String query, {
    int maxResults = 20,
  }) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url =
          'https://graph.microsoft.com/v1.0/me/messages?\$filter=contains(from/emailAddress/address,\'$encodedQuery\')&\$top=$maxResults&\$orderby=receivedDateTime desc';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${account.accessToken}',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final messages = data['value'] as List;

        return messages.map((message) {
          final from = message['from']['emailAddress'];
          return {
            'id': message['id'],
            'name': from['name'] ?? 'Unknown',
            'from': from['address'] ?? '',
            'message': message['subject'] ?? 'No Subject',
            'snippet': message['bodyPreview'] ?? '',
            'time': message['receivedDateTime'] ?? '',
            'avatar': 'https://via.placeholder.com/150',
            'htmlBody': message['body']['content'] ?? '',
            'contentType': message['body']['contentType'] ?? 'text',
            'hasAttachments': message['hasAttachments'] ?? false,
            'provider': "Outlook",
            'accountId': account.id,
            'accountName': account.displayName,
          };
        }).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching Outlook emails with query: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getMessage(String messageId) async {
    try {
      final response = await http.get(
        Uri.parse('https://graph.microsoft.com/v1.0/me/messages/$messageId'),
        headers: {
          'Authorization': 'Bearer ${account.accessToken}',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error getting Outlook message: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAttachments(String messageId) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://graph.microsoft.com/v1.0/me/messages/$messageId/attachments',
        ),
        headers: {
          'Authorization': 'Bearer ${account.accessToken}',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final attachments = data['value'] as List;

        // Filter out non-file attachments
        return attachments
            .where((attachment) {
              // Check if this is an actual file attachment
              final bool isFileAttachment =
                  attachment['@odata.type'] ==
                  '#microsoft.graph.fileAttachment';

              // Check if it has a valid name
              final bool hasValidName =
                  attachment['name'] != null &&
                  attachment['name'].toString().isNotEmpty;

              // Check if it has a valid content type
              final bool hasContentType = attachment['contentType'] != null;

              // Check if it has content (size > 0)
              final bool hasContent = (attachment['size'] ?? 0) > 0;

              // NEW: Check if it's NOT an inline image or embedded content
              final bool isNotInline = attachment['isInline'] != true;

              // NEW: Check if it doesn't have a contentId (used for HTML embedding)
              final bool hasNoContentId =
                  attachment['contentId'] == null ||
                  (attachment['contentId'] as String).isEmpty;

              // NEW: Check if filename doesn't match common email signature patterns
              final String filename =
                  (attachment['name'] ?? '').toString().toLowerCase();
              final bool isNotSignatureImage =
                  !filename.contains('signature') &&
                  !filename.contains('logo') &&
                  !filename.contains('image00') &&
                  !filename.contains('inline');

              // Only include true file attachments with valid properties that aren't inline content
              return isFileAttachment &&
                  hasValidName &&
                  hasContentType &&
                  hasContent &&
                  isNotInline &&
                  (hasNoContentId || isNotSignatureImage);
            })
            .map((attachment) {
              return {
                'id': attachment['id'],
                'filename': attachment['name'],
                'mimeType':
                    attachment['contentType'] ?? 'application/octet-stream',
                'size': attachment['size'] ?? 0,
                'downloadUrl':
                    'https://graph.microsoft.com/v1.0/me/messages/$messageId/attachments/${attachment['id']}',
                'isOutlook': true,
              };
            })
            .toList();
      }

      print(
        'Error fetching Outlook attachments: ${response.statusCode} - ${response.body}',
      );
      return [];
    } catch (e) {
      print('Error getting Outlook attachments: $e');
      return [];
    }
  }
}
