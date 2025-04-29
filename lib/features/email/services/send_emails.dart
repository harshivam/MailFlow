import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mail_merge/user/authentication/google_sign_in.dart';

class EmailSender {
  // Constructor to initialize with access token
  final String accessToken;

  EmailSender(this.accessToken);

  Future<bool> sendEmail({
    required String to,
    required String subject,
    required String body,
    List<String> cc = const [],
    List<String> bcc = const [],
  }) async {
    if (accessToken.isEmpty) return false;

    try {
      // Construct the email in MIME format
      final message = [
        'To: $to',
        if (cc.isNotEmpty) 'Cc: ${cc.join(', ')}',
        if (bcc.isNotEmpty) 'Bcc: ${bcc.join(', ')}',
        'Subject: $subject',
        'MIME-Version: 1.0',
        'Content-Type: text/plain; charset=UTF-8',
        'Content-Transfer-Encoding: 7bit',
        '',
        body,
      ].join('\r\n');

      // Encode to base64 URL format
      final bytes = utf8.encode(message);
      final encodedMessage = base64Url
          .encode(bytes)
          .replaceAll('+', '-')
          .replaceAll('/', '_');

      // Send the email using Gmail API
      final response = await http.post(
        Uri.parse(
          'https://gmail.googleapis.com/gmail/v1/users/me/messages/send',
        ),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({'raw': encodedMessage}),
      );

      print('Email send response: ${response.statusCode} ${response.body}');
      return response.statusCode == 200;
    } catch (e) {
      print('Error sending email: $e');
      return false;
    }
  }
}

// Utility function to get an EmailSender instance with the current token
Future<EmailSender?> getEmailSender() async {
  final token = await getGoogleAccessToken();
  if (token != null) {
    return EmailSender(token);
  }
  return null;
}
