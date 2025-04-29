import 'package:flutter/material.dart';
import 'package:mail_merge/features/attachments_hub/AttachmentsScreen.dart';
import 'package:mail_merge/features/vip_inox/VipScreen.dart';
import 'package:mail_merge/features/unsubscribe_manager/unsubscribe.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mail_merge/user/authentication/google_sign_in.dart';
import 'dart:math'; // For the min function
import 'package:mail_merge/settings/settings_screen.dart';
import 'package:mail_merge/user/authentication/add_email_accounts.dart';
import 'package:shimmer/shimmer.dart'; // Import shimmer package

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _selectedIndex = 0;
  String _accessToken = ""; // Initialize with empty string
  final _chatListKey = GlobalKey<_ChatListState>();

  @override
  void initState() {
    super.initState();
    _getAccessToken(); // Get token when app starts
  }

  // Update the _getAccessToken method to trigger fetchEmails via setState
  Future<void> _getAccessToken() async {
    final token = await getGoogleAccessToken();
    if (token != null && mounted) {
      setState(() {
        _accessToken = token;
        // Setting a new access token will automatically trigger fetchEmails in ChatList
        // because of the didUpdateWidget method in ChatList
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Create screens list inside build to use updated _accessToken
    final List<Widget> screens = [
      ChatList(key: _chatListKey, accessToken: _accessToken),
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
            onPressed: () async {
              // First check if we have a token
              final token = await getGoogleAccessToken();

              if (mounted) {
                setState(() {
                  _accessToken =
                      token ?? ""; // Update token (might be null if logged out)
                });

                // If we're on the home tab and have a valid token
                if (_selectedIndex == 0 && token != null) {
                  _chatListKey.currentState
                      ?.fetchEmails(); // Directly call refresh
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
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
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(avatar),
                ), // Avatar from network
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
                            _formatTime(time),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
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

  String _formatTime(String timeString) {
    if (timeString.isEmpty) return '';

    try {
      DateTime? date;
      const List<String> months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      try {
        date = DateTime.parse(timeString);
      } catch (_) {
        final RegExp dateRegex = RegExp(
          r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)',
          caseSensitive: false,
        );
        final match = dateRegex.firstMatch(timeString);
        if (match != null) {
          return '${match.group(1)} ${match.group(2)}';
        }
        if (timeString.contains(',')) {
          final parts = timeString.split(',');
          if (parts.length > 1) return parts[0];
        }
        return timeString.substring(0, timeString.length.clamp(0, 10));
      }

      final day = date!.day;
      final month = months[date.month - 1];
      return '$day $month';
    } catch (_) {
      return timeString.length > 10 ? timeString.substring(0, 10) : timeString;
    }
  }
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
  bool _hasMore = true;
  String? _nextPageToken;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
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
  void didUpdateWidget(ChatList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.accessToken != oldWidget.accessToken &&
        widget.accessToken.isNotEmpty) {
      chatData.clear();
      _nextPageToken = null;
      _hasMore = true;
      fetchEmails();
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
      final uri = Uri.parse(
        'https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=25${_nextPageToken != null ? '&pageToken=$_nextPageToken' : ''}',
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${widget.accessToken}',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final messages = data['messages'] as List?;
        _nextPageToken = data['nextPageToken'];
        _hasMore = _nextPageToken != null;

        if (messages == null || messages.isEmpty) {
          setState(() => _isLoading = false);
          return;
        }

        for (var message in messages) {
          final messageId = message['id'];

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
            final emailData = json.decode(detailResponse.body);
            final snippet = emailData['snippet'] ?? '';
            final headers = emailData['payload']['headers'] as List;

            String subject = 'No Subject';
            String sender = 'Unknown';
            String time = '';
            String avatar =
                'https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png'; // Default avatar

            for (var header in headers) {
              if (header['name'] == 'Subject') {
                subject = header['value'];
              } else if (header['name'] == 'From') {
                sender = header['value'];
                if (sender.contains('<')) {
                  sender = sender.split('<')[0].trim();
                  if (sender.startsWith('"') && sender.endsWith('"')) {
                    sender = sender.substring(1, sender.length - 1);
                  }
                }
              } else if (header['name'] == 'Date') {
                time = header['value'];
              }
            }

            // Fetch the sender's avatar (profile image URL)
            final profileResponse = await http.get(
              Uri.parse(
                'https://people.googleapis.com/v1/people/me?personFields=photos',
              ),
              headers: {'Authorization': 'Bearer ${widget.accessToken}'},
            );
            if (profileResponse.statusCode == 200) {
              final profileData = json.decode(profileResponse.body);
              final photos = profileData['photos'] as List?;
              if (photos != null && photos.isNotEmpty) {
                avatar = photos.first['url']; // Get the profile photo URL
              }
            }

            chatData.add({
              "name": sender,
              "message": subject,
              "snippet": snippet,
              "time": time,
              "avatar": avatar,
            });
          }
        }

        setState(() {
          _isLoading = false;
        });
      } else {
        print('Failed to fetch emails: ${response.body}');
        setState(() => _isLoading = false);
      }
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

    if (_isLoading && chatData.isEmpty) {
      return _buildShimmerEffect(); // Shimmer effect during loading
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

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: chatData.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == chatData.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final email = chatData[index];
        return ChatItem(
          name: email["name"] ?? "Unknown",
          message: email["message"] ?? "",
          time: email["time"] ?? "",
          snippet: email["snippet"] ?? "",
          avatar:
              email["avatar"] ??
              "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png", // Default avatar
        );
      },
    );
  }

  // Shimmer effect while loading
  Widget _buildShimmerEffect() {
    return ListView.builder(
      itemCount: 10,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Card(
              elevation: 0.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    CircleAvatar(radius: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 120,
                            height: 10,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 150,
                            height: 10,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
