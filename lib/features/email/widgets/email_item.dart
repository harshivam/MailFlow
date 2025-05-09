import 'package:flutter/material.dart';
import 'package:mail_merge/utils/date_formatter.dart';
import 'package:mail_merge/features/email/screens/email_detail_screen.dart';

class EmailItem extends StatelessWidget {
  final String name;
  final String subject;
  final String time;
  final String avatar;
  final String snippet;
  final Map<String, dynamic>? emailData;

  const EmailItem({
    super.key,
    required this.name,
    required this.subject,
    required this.time,
    required this.avatar,
    this.snippet = "",
    this.emailData,
  });

  @override
  Widget build(BuildContext context) {
    // Extract provider and account information if available
    final String? provider = emailData?["provider"];
    final String? accountName = emailData?["accountName"];
    final bool hasProviderInfo = provider != null && accountName != null;

    return Card(
      elevation: 0, // Remove shadow
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey[300]!,
          width: 0.5,
        ), // Add thin light grey outline
      ),
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: InkWell(
        onTap: () {
          if (emailData != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EmailDetailScreen(email: emailData!),
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(avatar),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatEmailDate(time),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        if (hasProviderInfo) ...[
                          const SizedBox(height: 2),
                          // Provider badge - shows account and service info
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _getProviderColor(
                                provider,
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$accountName ($provider)',
                              style: TextStyle(
                                fontSize: 10,
                                color: _getProviderColor(provider),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          subject,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 52.0, top: 4.0),
                child: Text(
                  snippet.isNotEmpty ? snippet : "No preview available",
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to get colors based on email provider
  Color _getProviderColor(String provider) {
    switch (provider.toLowerCase()) {
      case 'gmail':
        return Colors.red;
      case 'outlook':
        return Colors.blue;
      case 'rediffmail':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
