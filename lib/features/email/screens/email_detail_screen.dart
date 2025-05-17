import 'package:flutter/material.dart';
import 'package:mail_merge/features/email/widgets/simple_html_viewer.dart';
import 'package:mail_merge/user/authentication/outlook_email_service.dart';
import 'package:mail_merge/user/repository/account_repository.dart';
import 'package:mail_merge/utils/date_formatter.dart';
import 'package:mail_merge/features/email/screens/compose_email_screen.dart';
import 'package:mail_merge/features/vip_inbox/services/contact_service.dart';
import 'package:mail_merge/features/vip_inbox/models/contact.dart';
import 'package:mail_merge/features/attachments_hub/models/attachment.dart';
import 'package:mail_merge/features/attachments_hub/widgets/attachment_grid.dart';

class EmailDetailScreen extends StatefulWidget {
  final Map<String, dynamic> email;

  const EmailDetailScreen({super.key, required this.email});

  @override
  State<EmailDetailScreen> createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends State<EmailDetailScreen> {
  bool _isRead = true; // Assume email is read when opened
  bool _isVip = false; // Track if sender is in VIP list
  bool _isProcessing = false; // Track if VIP operation is in progress

  @override
  void initState() {
    super.initState();
    _isRead = widget.email["isRead"] ?? true;
    _checkIfVip();
    _checkForAttachments(); // Changed from _loadEmailAttachments
  }

  // Check if the sender is already in VIP list
  Future<void> _checkIfVip() async {
    try {
      final String senderEmail = widget.email["from"] ?? "";
      if (senderEmail.isEmpty) return;

      final vipContacts = await ContactService.getVipContacts();
      final isVip = vipContacts.any(
        (contact) => contact.email.toLowerCase() == senderEmail.toLowerCase(),
      );

      if (mounted) {
        setState(() {
          _isVip = isVip;
        });
      }
    } catch (e) {
      print('Error checking VIP status: $e');
    }
  }

  // Toggle VIP status
  Future<void> _toggleVipStatus() async {
    if (_isProcessing) return;

    final String senderEmail = widget.email["from"] ?? "";
    final String senderName = widget.email["name"] ?? "Unknown";

    if (senderEmail.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sender email not available')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      if (_isVip) {
        // Remove from VIP
        await ContactService.removeContact(senderEmail);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Removed from VIP list')),
          );
        }
      } else {
        // Add to VIP
        final newContact = Contact(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: senderName,
          email: senderEmail,
          isVip: true,
        );
        await ContactService.addContact(newContact.name, newContact.email);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Added to VIP list')));
        }
      }

      // Update the state
      if (mounted) {
        setState(() {
          _isVip = !_isVip;
          _isProcessing = false;
        });
      }
    } catch (e) {
      print('Error updating VIP status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating VIP status: ${e.toString()}')),
        );
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _toggleReadStatus() {
    setState(() {
      _isRead = !_isRead;
    });

    // Show appropriate message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isRead ? 'Marked as read' : 'Marked as unread')),
    );
  }

  // Check for email attachments
  void _checkForAttachments() {
    // Just check if email has an 'attachments' field or a hasAttachments flag
    final List<dynamic> existingAttachments =
        widget.email['attachments'] as List<dynamic>? ?? [];
    final bool hasAttachmentFlag = widget.email['hasAttachments'] == true;

    print('Email has ${existingAttachments.length} attachments');
    print('Email hasAttachments flag: $hasAttachmentFlag');

    // We don't need to do anything else - just use what's already there
  }

  @override
  Widget build(BuildContext context) {
    // Extract the sender's email address
    final String senderEmail = widget.email["from"] ?? "";

    return Scaffold(
      appBar: AppBar(
        title: const Text('Email'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Email moved to trash')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              _showEmailOptions(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.email["message"] ?? "No Subject",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Sender info row with avatar
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundImage: NetworkImage(
                          widget.email["avatar"] ??
                              "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png",
                        ),
                        radius: 20,
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
                                    widget.email["name"] ?? "Unknown",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                if (_isVip)
                                  const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 18,
                                  ),
                              ],
                            ),
                            if (widget.email["accountName"] != null &&
                                widget.email["provider"] != null) ...{
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${widget.email["accountName"]} (${widget.email["provider"]})',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue[800],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            },
                            Text(
                              senderEmail,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatEmailDate(widget.email["time"] ?? ""),
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  _buildEmailContent(),
                ],
              ),
            ),
          ],
        ),
      ),
      // Add floating action button for compose email
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => ComposeEmailScreen(
                    recipientEmail:
                        senderEmail, // Pre-fill the recipient's email
                  ),
            ),
          );
        },
        tooltip: 'Compose Email',
        child: const Icon(Icons.edit),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon: const Icon(Icons.reply),
                tooltip: 'Reply',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reply coming soon')),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.reply_all),
                tooltip: 'Reply All',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reply All coming soon')),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.forward),
                tooltip: 'Forward',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Forward coming soon')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Update the _buildEmailContent method

  Widget _buildEmailContent() {
    // Check if there's any content or attachments
    final hasAttachments =
        (widget.email['attachments'] as List<dynamic>?)?.isNotEmpty == true ||
        widget.email['hasAttachments'] == true;

    // First check if we have meaningful HTML content
    if (widget.email['htmlBody'] != null &&
        !_isHtmlContentEffectivelyEmpty(widget.email['htmlBody'].toString())) {
      print("Using HTML viewer for email content");
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SimpleHtmlViewer(
            htmlContent: widget.email['htmlBody'],
            key: ValueKey('html-${widget.email['id']}'),
          ),
          if (hasAttachments) _buildAttachments(),
        ],
      );
    }
    // Special case for Outlook emails - they use body.content structure
    else if (widget.email['provider'] == 'Outlook' &&
        widget.email['body'] != null) {
      final contentType =
          widget.email['body']['contentType']?.toString().toLowerCase() ?? '';
      final content = widget.email['body']['content']?.toString() ?? '';

      if (content.isNotEmpty) {
        if (contentType.contains('html')) {
          print("Using Outlook HTML content: ${content.length} chars");
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SimpleHtmlViewer(
                htmlContent: content,
                key: ValueKey('outlook-html-${widget.email['id']}'),
              ),
              if (hasAttachments) _buildAttachments(),
            ],
          );
        } else {
          // Plain text content
          print("Using Outlook plain text content: ${content.length} chars");
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SelectableText(
                  content,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (hasAttachments) _buildAttachments(),
            ],
          );
        }
      }
    }
    // Then check for plain text
    else if (widget.email['plainTextBody'] != null &&
        widget.email['plainTextBody'].toString().isNotEmpty) {
      print("Using plain text for email content");
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            widget.email['plainTextBody'],
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
          if (hasAttachments) _buildAttachments(),
        ],
      );
    }
    // Finally fall back to snippet
    else if (widget.email['snippet'] != null &&
        widget.email['snippet'].toString().isNotEmpty) {
      print("Using snippet for email content");
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.email['snippet'],
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
          if (hasAttachments) _buildAttachments(),
        ],
      );
    }
    // If no content but has attachments, just show attachments
    else if (hasAttachments) {
      return _buildAttachments();
    }

    // No content and no attachments
    return const Center(
      child: Text(
        'No content available',
        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
      ),
    );
  }

  void _showEmailOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Toggle read/unread based on current state
              ListTile(
                leading: Icon(
                  _isRead ? Icons.mark_email_unread : Icons.mark_email_read,
                ),
                title: Text(_isRead ? 'Mark as unread' : 'Mark as read'),
                onTap: () {
                  Navigator.pop(context);
                  _toggleReadStatus();
                },
              ),
              ListTile(
                leading: const Icon(Icons.archive),
                title: const Text('Archive'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Email archived')),
                  );
                },
              ),
              // Toggle VIP status based on current state
              ListTile(
                leading: Icon(
                  _isVip ? Icons.star : Icons.star_border,
                  color: _isVip ? Colors.amber : null,
                ),
                title: Text(_isVip ? 'Remove from VIP' : 'Add to VIP'),
                onTap: () {
                  Navigator.pop(context);
                  _toggleVipStatus();
                },
              ),
            ],
          ),
    );
  }

  Widget _buildAttachments() {
    // Check both 'attachments' field and 'hasAttachments' flag
    final List<dynamic> attachments =
        widget.email['attachments'] as List<dynamic>? ?? [];

    // Debug info
    print("Attachments list length: ${attachments.length}");
    print("hasAttachments flag: ${widget.email['hasAttachments']}");

    // If no attachments but hasAttachments flag is true, we need to fetch them for Outlook
    if (attachments.isEmpty &&
        widget.email['hasAttachments'] == true &&
        widget.email['provider'] == 'Outlook') {
      // Show loading placeholder
      return FutureBuilder(
        future: _fetchOutlookAttachments(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasData && (snapshot.data as List).isNotEmpty) {
            final emailAttachments = snapshot.data as List<EmailAttachment>;
            return _buildAttachmentGrid(emailAttachments);
          } else {
            return const SizedBox.shrink();
          }
        },
      );
    }

    if (attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    // Convert the attachment data to EmailAttachment objects
    final emailAttachments =
        attachments
            .map((attachment) => _convertToEmailAttachment(attachment))
            .toList();

    return _buildAttachmentGrid(emailAttachments);
  }

  // Helper method to build the attachment grid with header
  Widget _buildAttachmentGrid(List<EmailAttachment> attachments) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Row(
            children: [
              const Icon(Icons.attach_file, size: 18, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Text(
                'Attachments (${attachments.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.blueGrey,
                ),
              ),
            ],
          ),
        ),
        AttachmentGrid(
          attachments: attachments,
          onAttachmentTap: (attachment) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Opening ${attachment.name}...')),
            );
          },
        ),
      ],
    );
  }

  // Add this method to fetch Outlook attachments on demand
  Future<List<EmailAttachment>> _fetchOutlookAttachments() async {
    try {
      final messageId = widget.email['id'];
      final accountId = widget.email['accountId'];

      if (messageId == null || accountId == null) {
        return [];
      }

      // Get the account and create the service
      final accountRepo = AccountRepository();
      final account = await accountRepo.getAccountById(accountId);
      final service = OutlookEmailService(account);

      // Fetch attachments
      final attachmentData = await service.getAttachments(messageId);

      // Convert to EmailAttachment objects
      return attachmentData.map((attachment) {
        return EmailAttachment(
          id: attachment['id'] ?? '',
          name: attachment['filename'] ?? 'Unknown',
          contentType: attachment['mimeType'] ?? 'application/octet-stream',
          size: attachment['size'] ?? 0,
          downloadUrl: attachment['downloadUrl'] ?? '',
          emailId: messageId,
          emailSubject: widget.email['message'] ?? '',
          senderName: widget.email['name'] ?? '',
          senderEmail: widget.email['from'] ?? '',
          date: widget.email['_dateTime'] ?? DateTime.now(),
          accountId: accountId,
        );
      }).toList();
    } catch (e) {
      print('Error fetching Outlook attachments: $e');
      return [];
    }
  }

  // Optimize the attachment conversion by removing redundant checks
  EmailAttachment _convertToEmailAttachment(Map<String, dynamic> attachment) {
    final email = widget.email;

    return EmailAttachment(
      id: attachment['id'] ?? '',
      name: attachment['filename'] ?? 'Unknown',
      contentType: attachment['mimeType'] ?? 'application/octet-stream',
      size: attachment['size'] ?? 0,
      downloadUrl: attachment['downloadUrl'] ?? '',
      emailId: email['id'] ?? '',
      emailSubject: email['message'] ?? '',
      senderName: email['name'] ?? '',
      senderEmail: email['from'] ?? '',
      date: DateTime.tryParse(email['time'] ?? '') ?? DateTime.now(),
      accountId: email['accountId'] ?? '',
    );
  }

  // Add this method to EmailDetailScreen class
  bool _isHtmlContentEffectivelyEmpty(String? html) {
    if (html == null || html.isEmpty) return true;

    // First check: strip whitespace
    final trimmed = html.trim();
    if (trimmed.isEmpty) return true;

    // Second check: common empty HTML patterns
    final lowerTrimmed = trimmed.toLowerCase();

    // Check for empty or nearly empty HTML structures
    final emptyHtmlPatterns = [
      r'<html[^>]*>(\s*)<\/html>',
      r'<html[^>]*>(\s*)<body[^>]*>(\s*)<\/body>(\s*)<\/html>',
      r'<div[^>]*>(\s*)<\/div>',
      r'<p[^>]*>(\s*)<\/p>',
      r'&nbsp;',
      r'<br[^>]*>',
    ];

    // Replace all these patterns with empty string
    String simplified = lowerTrimmed;
    for (final pattern in emptyHtmlPatterns) {
      simplified = simplified.replaceAll(RegExp(pattern), '');
    }

    // Remove all HTML tags for final check
    simplified = simplified.replaceAll(RegExp(r'<[^>]+>'), '').trim();

    // If after removing everything, we have empty string or just whitespace, it's empty
    return simplified.isEmpty || RegExp(r'^\s*$').hasMatch(simplified);
  }
}
