import 'package:flutter/material.dart';
import 'package:mail_merge/features/email/widgets/email_item.dart';
import 'package:mail_merge/features/email/widgets/email_shimmer.dart';
import 'package:mail_merge/features/email/services/email_service.dart';
import 'package:mail_merge/user/authentication/add_email_accounts.dart';

class EmailListScreen extends StatefulWidget {
  final String accessToken;

  const EmailListScreen({super.key, required this.accessToken});

  @override
  State<EmailListScreen> createState() => EmailListScreenState();
}

class EmailListScreenState extends State<EmailListScreen> {
  List<Map<String, dynamic>> emailData = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _nextPageToken;
  final ScrollController _scrollController = ScrollController();
  late EmailService _emailService;

  @override
  void initState() {
    super.initState();
    _emailService = EmailService(widget.accessToken);
    
    if (widget.accessToken.isNotEmpty) {
      fetchEmails();
    }

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        fetchEmails();
      }
    });
  }

  @override
  void didUpdateWidget(EmailListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.accessToken != oldWidget.accessToken) {
      _emailService = EmailService(widget.accessToken);
      
      if (widget.accessToken.isNotEmpty) {
        emailData.clear();
        _nextPageToken = null;
        _hasMore = true;
        fetchEmails();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> fetchEmails() async {
    if (widget.accessToken.isEmpty || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _emailService.fetchEmails(pageToken: _nextPageToken);
      
      setState(() {
        emailData.addAll(result.emails);
        _nextPageToken = result.nextPageToken;
        _hasMore = result.hasMore;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching emails: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.accessToken.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Sign in to view your emails"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddEmailAccountsPage(),
                  ),
                );
              },
              child: const Text("Add Email Account"),
            ),
          ],
        ),
      );
    }

    if (_isLoading && emailData.isEmpty) {
      return const EmailShimmerList(); // Shimmer effect during loading
    }

    if (emailData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("No emails found"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: fetchEmails,
              child: const Text("Refresh"),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: emailData.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == emailData.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final email = emailData[index];
        return EmailItem(
          name: email["name"] ?? "Unknown",
          subject: email["message"] ?? "",
          time: email["time"] ?? "",
          snippet: email["snippet"] ?? "",
          avatar: email["avatar"] ??
              "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png",
        );
      },
    );
  }
}