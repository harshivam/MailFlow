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

class EmailService {
  final String accessToken;

  EmailService(this.accessToken);

  Future<EmailPageResult> fetchEmails({String? pageToken}) async {
    if (accessToken.isEmpty) {
      return EmailPageResult(emails: [], nextPageToken: null, hasMore: false);
    }

    try {
      final uri = Uri.parse(
        'https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=25${pageToken != null ? '&pageToken=$pageToken' : ''}',
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final messages = data['messages'] as List?;
        final nextPageToken = data['nextPageToken'];
        final hasMore = nextPageToken != null;

        if (messages == null || messages.isEmpty) {
          return EmailPageResult(emails: [], nextPageToken: null, hasMore: false);
        }

        List<Map<String, dynamic>> emailsData = [];

        for (var message in messages) {
          final messageId = message['id'];
          final email = await _fetchEmailDetails(messageId);
          if (email != null) {
            emailsData.add(email);
          }
        }

        return EmailPageResult(
          emails: emailsData,
          nextPageToken: nextPageToken,
          hasMore: hasMore,
        );
      } else {
        throw Exception('Failed to fetch emails: ${response.body}');
      }
    } catch (e) {
      print('Error in fetchEmails: $e');
      rethrow;
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

        String subject = 'No Subject';
        String sender = 'Unknown';
        String time = '';
        String avatar =
            'https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png';

        for (var header in headers) {
          if (header['name'] == 'Subject') {
            subject = header['value'];
          } else if (header['name'] == 'From') {
            sender = header['value'];
            if (sender.contains('<')) {
              sender = sender.split('<')[0].trim();
              if (sender.startsWith('"') && sender.endsWith('"')) {
                sender = sender.substring(1, sender.length - 1);
              }
            }
          } else if (header['name'] == 'Date') {
            time = header['value'];
          }
        }

        // Try to get user's profile picture
        try {
          final profileResponse = await http.get(
            Uri.parse(
              'https://people.googleapis.com/v1/people/me?personFields=photos',
            ),
            headers: {'Authorization': 'Bearer $accessToken'},
          );
          if (profileResponse.statusCode == 200) {
            final profileData = json.decode(profileResponse.body);
            final photos = profileData['photos'] as List?;
            if (photos != null && photos.isNotEmpty) {
              avatar = photos.first['url'];
            }
          }
        } catch (e) {
          // Silently continue if profile picture fetch fails
          print('Error fetching profile picture: $e');
        }

        return {
          "id": messageId,
          "name": sender,
          "message": subject,
          "snippet": snippet,
          "time": time,
          "avatar": avatar,
        };
      }
      return null;
    } catch (e) {
      print('Error fetching email details: $e');
      return null;
    }
  }
}