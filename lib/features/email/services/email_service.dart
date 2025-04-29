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
      // Use a smaller batch size to load initial emails faster
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

        // Use parallel processing for fetching email details
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

        String subject = 'No Subject';
        String sender = 'Unknown';
        String from = ''; // Add this line
        String time = '';
        String avatar =
            'https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png';

        for (var header in headers) {
          if (header['name'] == 'Subject') {
            subject = header['value'];
          } else if (header['name'] == 'From') {
            sender = header['value'];
            from = header['value']; // Add this line
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

        // Add 'from' to your return value
        return {
          "id": messageId,
          "name": sender,
          "from": from, // Add this line
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

  // Add this method to fetch emails with a specific query
  Future<List<Map<String, dynamic>>> fetchEmailsWithQuery(
    String query, {
    int maxResults = 15, // Reduced for faster loading
  }) async {
    if (accessToken.isEmpty) {
      return [];
    }

    try {
      final response = await http.get(
        Uri.parse(
          'https://www.googleapis.com/gmail/v1/users/me/messages?q=$query&maxResults=$maxResults',
        ),
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final messages = data['messages'] as List<dynamic>?;

        if (messages == null || messages.isEmpty) {
          return [];
        }

        // Use parallel processing with Future.wait for better performance
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
}
