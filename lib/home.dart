// This file is now replaced by the new structure
// You can keep it temporarily for reference, then delete it once migration is complete

import 'package:flutter/material.dart';
import 'package:mail_merge/navigation/home_navigation.dart';

// This redirects to the new home navigation component
class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeNavigation();
  }
}
