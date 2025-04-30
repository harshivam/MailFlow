import 'package:mail_merge/user/models/email_account.dart';



class ImapConfig {
  final String host;
  final int port;
  final bool isSecure;
  
  ImapConfig({required this.host, required this.port, this.isSecure = true});
  
  // Common providers
  static ImapConfig forOutlook() => ImapConfig(
    host: 'outlook.office365.com',
    port: 993,
  );
  
  static ImapConfig forRediffmail() => ImapConfig(
    host: 'imap.rediffmail.com',
    port: 993,
  );
}