import 'package:flutter/material.dart';
import 'package:mail_merge/attachments_hub/AttachmentsScreen.dart';
import 'package:mail_merge/vip_inox/VipScreen.dart';
import 'package:mail_merge/unsubscribe_manager/unsubscribe.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const ChatList(), // Home Screen
    const VipScreen(), // VIP Screen
    const Attachmentsscreen(), // Attachments Screen
    const UnsubscribeScreen(), // Unsubscribe Screen
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(),
      body: IndexedStack(index: _selectedIndex, children: _screens),
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
            icon: Transform.scale(
              scale: 0.8, // Scale down the Attachments icon
              child: Icon(Icons.attach_file),
            ),
            label: "Attachments",
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.unsubscribe), label: "Unsubscribe"),
        ],
        onTap: _onItemTapped,
      ),
    );
  }
}

// 📌 App Bar
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

// 📌 Chat List Widget (Stateful for API integration)
class ChatList extends StatefulWidget {
  const ChatList({super.key});

  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  List<Map<String, String>> chatData = [];

  @override
  void initState() {
    super.initState();
    // Placeholder for API call in the future
    fetchEmails();
  }

  void fetchEmails() {
    setState(() {
      chatData = [
        {
          "name": "Peter",
          "message": "Thanks",
          "time": "11:01 AM",
          "avatar": "assets/images/profile_photo.png",
        },
        {
          "name": "John Smith",
          "message": "Yay, I did it, thanks.",
          "time": "10:20 AM",
          "avatar": "assets/images/profile_photo.png",
        },
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: chatData.length,
      itemBuilder: (context, index) {
        return ChatItem(
          name: chatData[index]["name"]!,
          message: chatData[index]["message"]!,
          time: chatData[index]["time"]!,
          avatar: chatData[index]["avatar"]!,
        );
      },
    );
  }
}

// 📌 Chat Item Widget
class ChatItem extends StatelessWidget {
  final String name;
  final String message;
  final String time;
  final String avatar;

  const ChatItem({
    super.key,
    required this.name,
    required this.message,
    required this.time,
    required this.avatar,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(backgroundImage: AssetImage(avatar)),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(message, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Text(
        time,
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      onTap: () {
        // Handle tap event
      },
    );
  }
}
