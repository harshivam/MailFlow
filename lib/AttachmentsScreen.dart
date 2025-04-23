import 'package:flutter/material.dart';

class Attachmentsscreen extends StatefulWidget {
  const Attachmentsscreen({super.key});

  @override
  State<Attachmentsscreen> createState() => _AttachmentsscreenState();
}

class _AttachmentsscreenState extends State<Attachmentsscreen> {
  List<Map<String, String>> attachments = [
    {
      "name": "Peter",
      "message": "Here's the invoice.pdf",
      "time": "10:45 AM",
      "file": "invoice.pdf"
    },
    {
      "name": "Lisa",
      "message": "Check out the report.docx",
      "time": "09:30 AM",
      "file": "report.docx"
    },
    {
      "name": "John",
      "message": "Image attached: selfie.png",
      "time": "08:10 AM",
      "file": "selfie.png"
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Attachments", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () {
              // Search action
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,  // This creates 3 columns
            crossAxisSpacing: 8.0,  // Spacing between columns
            mainAxisSpacing: 8.0,   // Spacing between rows
          ),
          itemCount: attachments.length,
          itemBuilder: (context, index) {
            final attachment = attachments[index];
            return GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text("Opening ${attachment["file"]}..."),
                ));
              },
              child: Card(
                elevation: .5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.attach_file, color: Colors.blue, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        attachment["name"]!,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        attachment["message"]!,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
