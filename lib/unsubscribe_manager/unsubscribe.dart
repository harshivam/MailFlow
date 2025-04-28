import 'package:flutter/material.dart';

class UnsubscribeScreen extends StatefulWidget {
  const UnsubscribeScreen({super.key});

  @override
  State<UnsubscribeScreen> createState() => _UnsubscribeScreenState();
}

class _UnsubscribeScreenState extends State<UnsubscribeScreen> {
  List<Map<String, dynamic>> emailList = [
    {
      "name": "Peter",
      "message": "Thanks",
      "time": "11:01 AM",
      "selected": false,
    },
    {
      "name": "John Smith",
      "message": "Yay, I did it, thanks.",
      "time": "10:20 AM",
      "selected": false,
    },
    {
      "name": "Nelly",
      "message": "I'll send you a screenshot",
      "time": "10:20 AM",
      "selected": false,
    },
    {
      "name": "Cold pink rabbit",
      "message": "Good afternoon, haven't heard back...",
      "time": "10:15 AM",
      "selected": false,
    },
    {
      "name": "Ola",
      "message": "Eli: Good afternoon, haven't heard back...",
      "time": "10:01 AM",
      "selected": false,
    },
    {
      "name": "Richard Tomson",
      "message": "Eon: Your manager will be online soon.",
      "time": "9:19 AM",
      "selected": false,
    },
  ];

  bool selectAll = false;

  void _toggleSelectAll(bool? value) {
    setState(() {
      selectAll = value ?? false;
      for (var email in emailList) {
        email["selected"] = selectAll;
      }
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      emailList[index]["selected"] = !emailList[index]["selected"];
      selectAll = emailList.every((email) => email["selected"]);
    });
  }

  void _unsubscribeEmail(int index) {
    setState(() {
      emailList.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: Column(
        children: [
          // 📌 Select All Checkbox
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Checkbox(value: selectAll, onChanged: _toggleSelectAll),
                const Text("Select All"),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: emailList.length,
              itemBuilder: (context, index) {
                return UnsubscribeItem(
                  name: emailList[index]["name"],
                  message: emailList[index]["message"],
                  time: emailList[index]["time"],
                  selected: emailList[index]["selected"],
                  onTap: () => _toggleSelection(index),
                  onUnsubscribe: () => _unsubscribeEmail(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// 📌 Unsubscribe List Item with Icon Instead of Checkbox
class UnsubscribeItem extends StatelessWidget {
  final String name;
  final String message;
  final String time;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onUnsubscribe;

  const UnsubscribeItem({
    super.key,
    required this.name,
    required this.message,
    required this.time,
    required this.selected,
    required this.onTap,
    required this.onUnsubscribe,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: IconButton(
        icon: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected ? Colors.blue : Colors.grey,
        ),
        onPressed: onTap,
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(message, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: ElevatedButton(
        onPressed: onUnsubscribe,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        child: const Text("Unsubscribe"),
      ),
    );
  }
}
