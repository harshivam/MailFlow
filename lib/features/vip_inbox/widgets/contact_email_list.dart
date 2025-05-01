import 'package:flutter/material.dart';
import 'package:mail_merge/features/email/widgets/email_item.dart';

class ContactEmailList extends StatelessWidget {
  final List<Map<String, dynamic>> emails;
  final String contactEmail;
  final String? contactName;
  final VoidCallback onBackPressed;
  final Future<void> Function() onRefresh;

  const ContactEmailList({
    super.key,
    required this.emails,
    required this.contactEmail,
    this.contactName,
    required this.onBackPressed,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Back button header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBackPressed,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  contactName ?? contactEmail,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // Show email list
        Expanded(
          child: RefreshIndicator(
            onRefresh: onRefresh,
            child: _buildEmailList(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailList() {
    if (emails.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.email_outlined, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No emails found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'No emails from ${contactName ?? contactEmail}',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Use a key based on contact email to preserve scroll position
    return ListView.builder(
      key: PageStorageKey<String>(contactEmail),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: emails.length,
      itemBuilder: (context, index) {
        final email = emails[index];
        return Card(
          elevation: 0, // Remove shadow
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[300]!, width: 0.5), // Add thin light grey outline
          ),
          child: EmailItem(
            name: email["name"] ?? "Unknown",
            subject: email["message"] ?? "",
            time: email["time"] ?? "",
            snippet: email["snippet"] ?? "",
            avatar: email["avatar"] ??
                "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png",
            emailData: email,
          ),
        );
      },
    );
  }
}
