import 'package:flutter/material.dart';
import 'package:mail_merge/utils/date_formatter.dart';
import 'package:mail_merge/features/email/screens/compose_email_screen.dart';
import 'package:mail_merge/features/vip_inbox/services/contact_service.dart';
import 'package:mail_merge/features/vip_inbox/models/contact.dart';

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
    // Initialize based on email read status if available
    _isRead = widget.email["isRead"] ?? true;
    _checkIfVip();
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.email["message"] ?? "No Subject",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
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
                      Text(
                        senderEmail,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
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
            Text(
              widget.email["snippet"] ?? "No content",
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            if (widget.email["body"] != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  widget.email["body"],
                  style: const TextStyle(fontSize: 16, height: 1.5),
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
}
