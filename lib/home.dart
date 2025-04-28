import 'package:flutter/material.dart';
import 'package:mail_merge/attachments_hub/AttachmentsScreen.dart';
import 'package:mail_merge/vip_inox/VipScreen.dart';
import 'package:mail_merge/unsubscribe_manager/unsubscribe.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mail_merge/user/authentication/google_sign_in.dart';
import 'dart:math'; // For the min function

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _selectedIndex = 0;
  String _accessToken = ""; // Initialize with empty string

  @override
  void initState() {
    super.initState();
    _getAccessToken(); // Get token when app starts
  }

  Future<void> _getAccessToken() async {
    final token = await getGoogleAccessToken();
    if (token != null && mounted) {
      setState(() {
        _accessToken = token;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Create screens list inside build to use updated _accessToken
    final List<Widget> screens = [
      ChatList(accessToken: _accessToken), // Pass current access token
      const VipScreen(),
      const Attachmentsscreen(),
      const UnsubscribeScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Mail Merge", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: () {
              _getAccessToken(); // Refresh token
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        showUnselectedLabels: false,
        showSelectedLabels: false,
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          const BottomNavigationBarItem(icon: Icon(Icons.star), label: "VIP"),
          BottomNavigationBarItem(
            icon: Transform.scale(scale: 0.8, child: Icon(Icons.attach_file)),
            label: "Attachments",
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.unsubscribe),
            label: "Unsubscribe",
          ),
        ],
        onTap: _onItemTapped,
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text("Mail Merge", style: TextStyle(color: Colors.black)),
      centerTitle: true,
      backgroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.black),
          onPressed: () {},
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class ChatList extends StatefulWidget {
  final String accessToken;

  const ChatList({super.key, required this.accessToken});

  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  List<Map<String, dynamic>> chatData = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.accessToken.isNotEmpty) {
      fetchEmails();
    }
  }

  @override
  void didUpdateWidget(ChatList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If access token has changed and is not empty, fetch emails
    if (widget.accessToken != oldWidget.accessToken &&
        widget.accessToken.isNotEmpty) {
      fetchEmails();
    }
  }

  Future<void> fetchEmails() async {
    if (widget.accessToken.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=10',
        ),
        headers: {
          'Authorization': 'Bearer ${widget.accessToken}',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        var messages = data['messages'];

        if (messages == null) {
          setState(() {
            _isLoading = false;
          });
          return;
        }

        List<Map<String, dynamic>> tempChatData = [];

        // Loop through messages and get their details
        for (var message in messages) {
          String messageId = message['id'];

          final detailResponse = await http.get(
            Uri.parse(
              'https://gmail.googleapis.com/gmail/v1/users/me/messages/$messageId',
            ),
            headers: {
              'Authorization': 'Bearer ${widget.accessToken}',
              'Accept': 'application/json',
            },
          );

          if (detailResponse.statusCode == 200) {
            var emailData = json.decode(detailResponse.body);

            String snippet = emailData['snippet'] ?? '';
            List headers = emailData['payload']['headers'];

            String subject = 'No Subject';
            String sender = 'Unknown';
            String time = '';

            for (var header in headers) {
              if (header['name'] == 'Subject') {
                subject = header['value'];
              } else if (header['name'] == 'From') {
                sender = header['value'];
                if (sender.contains('<')) {
                  sender = sender.split('<')[0].trim();
                  // Remove quotes if present
                  if (sender.startsWith('"') && sender.endsWith('"')) {
                    sender = sender.substring(1, sender.length - 1);
                  }
                }
              } else if (header['name'] == 'Date') {
                time = header['value'];
              }
            }

            tempChatData.add({
              "name": sender,
              "message": subject,
              "snippet": snippet,
              "time": time,
              "avatar": "assets/images/profile_photo.png",
            });
          }
        }

        // Update UI
        setState(() {
          chatData = tempChatData;
          _isLoading = false;
        });
      } else {
        print('Failed to fetch emails: ${response.body}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (error) {
      print('Error fetching emails: $error');
      setState(() {
        _isLoading = false;
      });
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
              onPressed: () async {
                await signInWithGoogle(context);
              },
              child: const Text("Sign in with Google"),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (chatData.isEmpty) {
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

    // Now we're actually returning the ListView instead of stopping at the placeholder
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: chatData.length,
      itemBuilder: (context, index) {
        return ChatItem(
          name: chatData[index]["name"] ?? "Unknown",
          message: chatData[index]["message"] ?? "",
          time: chatData[index]["time"] ?? "",
          snippet: chatData[index]["snippet"] ?? "",
          avatar:
              chatData[index]["avatar"] ?? "assets/images/profile_photo.png",
        );
      },
    );
  }
}

class ChatItem extends StatelessWidget {
  final String name;
  final String message;
  final String time;
  final String avatar;
  final String snippet;

  const ChatItem({
    super.key,
    required this.name,
    required this.message,
    required this.time,
    required this.avatar,
    this.snippet = "",
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(radius: 20, backgroundImage: AssetImage(avatar)),
                const SizedBox(width: 12),

                // Email content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sender name with timestamp moved here
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
                            _formatTime(time),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Subject only (time removed from here)
                      Text(
                        message,
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

            // Message preview
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
    );
  }

  // Helper method to format the time
  String _formatTime(String timeString) {
    if (timeString.isEmpty) return '';

    try {
      // Try to parse the RFC 2822 or similar format (standard email date format)
      DateTime? date;
      
      // List of month abbreviations
      const List<String> months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      
      try {
        // Try standard format first
        date = DateTime.parse(timeString);
      } catch (_) {
        // If direct parsing fails, try to extract from email date format
        final RegExp dateRegex = RegExp(
          r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)',
          caseSensitive: false
        );
        
        final match = dateRegex.firstMatch(timeString);
        if (match != null) {
          final day = match.group(1);
          final month = match.group(2);
          if (day != null && month != null) {
            return '$day $month'; // Return in "28 Apr" format
          }
        }
        
        // Fallback to just using the date portion if available
        if (timeString.contains(',')) {
          final parts = timeString.split(',');
          if (parts.length > 1) {
            return parts[0]; // Often this is day and month
          }
        }
        
        return timeString.substring(0, min(10, timeString.length));
      }
      
      // If we successfully parsed the date, format it nicely
      final day = date!.day;
      final month = months[date.month - 1]; // Get month abbreviation
      
      return '$day $month'; // Format as "28 Apr"
    } catch (e) {
      // If all else fails, just return a subset of the string
      return timeString.length > 10 ? timeString.substring(0, 10) : timeString;
    }
  }
}
