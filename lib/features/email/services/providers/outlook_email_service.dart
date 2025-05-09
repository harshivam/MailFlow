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
          'https://graph.microsoft.com/v1.0/me/messages?\$top=$maxResults&\$orderby=receivedDateTime desc';

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
      print('Error fetching Outlook emails: $e');
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
}
