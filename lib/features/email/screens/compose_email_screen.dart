import 'package:flutter/material.dart';
import 'package:mail_merge/features/email/services/send_emails.dart';

class ComposeEmailScreen extends StatefulWidget {
  final String? recipientEmail;

  const ComposeEmailScreen({super.key, this.recipientEmail});

  @override
  State<ComposeEmailScreen> createState() => _ComposeEmailScreenState();
}

class _ComposeEmailScreenState extends State<ComposeEmailScreen> {
  final TextEditingController _toController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  bool _isSending = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Pre-fill recipient email if provided
    if (widget.recipientEmail != null && widget.recipientEmail!.isNotEmpty) {
      _toController.text = widget.recipientEmail!;
    }
  }

  @override
  void dispose() {
    _toController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    if (_toController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a recipient email')),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    final emailSender = await getEmailSender();
    if (emailSender == null) {
      setState(() {
        _isSending = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You need to be signed in to send emails'),
          ),
        );
      }
      return;
    }

    final result = await emailSender.sendEmail(
      to: _toController.text,
      subject: _subjectController.text,
      body: _bodyController.text,
    );

    setState(() {
      _isSending = false;
    });

    if (mounted) {
      if (result) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email sent successfully')),
        );
        Navigator.pop(context); // Go back after sending
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to send email')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compose Email'),
        actions: [
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _isSending ? null : _sendEmail,
          ),
        ],
      ),
      body:
          _isSending
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _toController,
                      decoration: const InputDecoration(
                        labelText: 'To',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TextField(
                        controller: _bodyController,
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
