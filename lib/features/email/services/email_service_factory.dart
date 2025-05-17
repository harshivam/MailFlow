import 'package:mail_merge/features/email/services/email_service.dart';
import 'package:mail_merge/features/email/services/providers/imap_email_service.dart';
import 'package:mail_merge/user/authentication/outlook_email_service.dart';
import 'package:mail_merge/user/models/email_account.dart';

class EmailServiceFactory {
  static Future<dynamic> createService(EmailAccount account) async {
    switch (account.provider) {
      case AccountProvider.gmail:
        return EmailService(account.accessToken);
      case AccountProvider.outlook:
        return OutlookEmailService(account);
      case AccountProvider.rediffmail:
        return ImapEmailService(account);
    }
  }
}
