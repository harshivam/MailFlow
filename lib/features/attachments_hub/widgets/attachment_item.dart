import 'package:flutter/material.dart';
import 'package:mail_merge/features/attachments_hub/models/attachment.dart';
import 'package:mail_merge/features/email/screens/email_detail_screen.dart';
import 'package:mail_merge/utils/date_formatter.dart';
import 'package:url_launcher/url_launcher.dart';

class AttachmentItem extends StatelessWidget {
  final EmailAttachment attachment;

  const AttachmentItem({super.key, required this.attachment});

  // Helper method to get background color based on file type
  Color _getBackgroundColor() {
    if (attachment.contentType.contains('image')) return Colors.lightBlue[50]!;
    if (attachment.contentType.contains('pdf')) return Colors.red[50]!;
    if (attachment.contentType.contains('word') ||
        attachment.contentType.contains('document'))
      return Colors.blue[50]!;
    if (attachment.contentType.contains('excel') ||
        attachment.contentType.contains('spreadsheet'))
      return Colors.green[50]!;
    if (attachment.contentType.contains('presentation') ||
        attachment.contentType.contains('powerpoint'))
      return Colors.orange[50]!;
    if (attachment.contentType.contains('zip') ||
        attachment.contentType.contains('rar'))
      return Colors.purple[50]!;
    if (attachment.contentType.contains('audio')) return Colors.amber[50]!;
    if (attachment.contentType.contains('video')) return Colors.pink[50]!;
    return Colors.grey[50]!;
  }

  // Helper method to get icon color based on file type
  Color _getIconColor() {
    if (attachment.contentType.contains('image')) return Colors.lightBlue[700]!;
    if (attachment.contentType.contains('pdf')) return Colors.red[700]!;
    if (attachment.contentType.contains('word') ||
        attachment.contentType.contains('document'))
      return Colors.blue[700]!;
    if (attachment.contentType.contains('excel') ||
        attachment.contentType.contains('spreadsheet'))
      return Colors.green[700]!;
    if (attachment.contentType.contains('presentation') ||
        attachment.contentType.contains('powerpoint'))
      return Colors.orange[700]!;
    if (attachment.contentType.contains('zip') ||
        attachment.contentType.contains('rar'))
      return Colors.purple[700]!;
    if (attachment.contentType.contains('audio')) return Colors.amber[700]!;
    if (attachment.contentType.contains('video')) return Colors.pink[700]!;
    return Colors.grey[700]!;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!, width: 0.5),
      ),
      child: InkWell(
        onTap: () => _viewAttachment(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // File icon
              Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                  color: _getBackgroundColor(),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(
                    attachment.icon,
                    size: 40,
                    color: _getIconColor(),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // File name
              Text(
                attachment.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),

              // File size
              Text(
                attachment.formattedSize,
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),
              const SizedBox(height: 2),

              // Date
              Text(
                formatEmailDate(attachment.date.toIso8601String()),
                style: TextStyle(color: Colors.grey[700], fontSize: 13),
              ),

              const Spacer(),

              // From email text
              Text(
                'From: ${attachment.senderName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Method to open the attachment or show email
  void _viewAttachment(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.visibility),
                  title: const Text('View attachment'),
                  onTap: () {
                    Navigator.pop(context);
                    _openAttachment();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('View original email'),
                  onTap: () {
                    Navigator.pop(context);
                    // Navigate to email detail screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => EmailDetailScreen(
                              email: {
                                'id': attachment.emailId,
                                'accountId': attachment.accountId,
                                'message': attachment.emailSubject,
                              },
                            ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
    );
  }

  // Open attachment using URL launcher
  Future<void> _openAttachment() async {
    if (attachment.downloadUrl.isNotEmpty) {
      final url = Uri.parse(attachment.downloadUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      }
    }
  }
}
