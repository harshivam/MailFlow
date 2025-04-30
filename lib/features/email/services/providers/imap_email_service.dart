import 'package:enough_mail/enough_mail.dart';
import 'package:mail_merge/user/models/email_account.dart';

class ImapEmailService {
  final EmailAccount account;
  ImapClient? _imapClient;
  
  ImapEmailService(this.account);
  
  Future<void> connect() async {
    try {
      // First try to discover the IMAP settings automatically
      final config = await Discover.discover(account.email);
      
      if (config != null && config.preferredIncomingImapServer != null) {
        // Use discovered settings
        final server = config.preferredIncomingImapServer!;
        _imapClient = ImapClient(isLogEnabled: false);
        
        await _imapClient!.connectToServer(
          server.hostname!, 
          server.port!,
          isSecure: server.isSecureSocket,
        );
      } else {
        // Use default settings based on email provider
        final settings = _getDefaultSettings(account.provider);
        _imapClient = ImapClient(isLogEnabled: false);
        
        await _imapClient!.connectToServer(
          settings.host, 
          settings.port,
          isSecure: settings.isSecure,
        );
      }
      
      // For Outlook/Rediffmail authentication differs: 
      // Outlook typically uses OAuth2, Rediffmail uses password
      if (account.provider == AccountProvider.outlook) {
        await _imapClient!.authenticateWithOAuth2(
          account.email, 
          account.accessToken
        );
      } else {
        // For simplicity, when using normal passwords we store them in accessToken field
        await _imapClient!.login(account.email, account.accessToken);
      }
    } catch (e) {
      print('IMAP connection error: $e');
      throw Exception('Failed to connect to email server: $e');
    }
  }
  
  ImapConfig _getDefaultSettings(AccountProvider provider) {
    switch (provider) {
      case AccountProvider.outlook:
        return ImapConfig(host: 'outlook.office365.com', port: 993);
      case AccountProvider.rediffmail:
        return ImapConfig(host: 'imap.rediffmail.com', port: 993);
      default:
        throw Exception('Provider $provider not supported with IMAP');
    }
  }
  
  Future<List<Map<String, dynamic>>> fetchEmails({
    String? pageToken,
    int maxResults = 15,
  }) async {
    if (_imapClient == null || !_imapClient!.isLoggedIn) {
      await connect();
    }
    
    try {
      await _imapClient!.selectInbox();
      
      // Fetch most recent emails first
      final fetchId = pageToken != null 
          ? MessageSequence.fromRange(int.parse(pageToken), int.parse(pageToken) + maxResults - 1)
          : MessageSequence.fromAll();
      
      final fetchResult = await _imapClient!.fetchMessages(
        fetchId,
        '(ENVELOPE BODY.PEEK[TEXT])',
        changedSinceModSequence: 0
      );
      
      final emails = fetchResult.messages.map((message) {
        final from = message.from?.first;
        return {
          "id": message.sequenceId.toString(),
          "name": from?.personalName ?? from?.email ?? "Unknown",
          "from": from?.email ?? "",
          "message": message.decodeSubject() ?? "No Subject",
          "snippet": _extractSnippet(message),
          "time": message.decodeDate()?.toIso8601String() ?? "",
          "avatar": "https://via.placeholder.com/150",
          "provider": account.provider.displayName,
          "accountId": account.id,
        };
      }).toList();
      
      // Determine next page token
      String? nextPageToken;
      if (emails.isNotEmpty && emails.length >= maxResults) {
        final id = emails.last["id"];
        if (id != null) {
          nextPageToken = (int.parse(id) + 1).toString();
        }
      }
      
      return emails;
    } catch (e) {
      print('Error fetching emails via IMAP: $e');
      return [];
    }
  }
  
  String _extractSnippet(MimeMessage message) {
    final String? text = message.decodeTextPlainPart();
    if (text != null && text.isNotEmpty) {
      return text.length > 100 ? text.substring(0, 100) : text;
    }
    return "";
  }
  
  void dispose() {
    _imapClient?.logout();
  }
}

class ImapConfig {
  final String host;
  final int port;
  final bool isSecure;
  
  ImapConfig({
    required this.host, 
    required this.port, 
    this.isSecure = true
  });
}
