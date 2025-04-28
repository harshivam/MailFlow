import 'package:flutter/material.dart';

class VipScreen extends StatefulWidget {
  const VipScreen({super.key});

  @override
  State<VipScreen> createState() => _VipScreenState();
}

class _VipScreenState extends State<VipScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: const Center(
        child: Text("VIP Screen"),
      ),
    );
  }
}