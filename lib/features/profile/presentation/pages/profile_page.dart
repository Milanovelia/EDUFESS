import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_page.dart';

/// Profile tab. M0 placeholder — no auth, roles, or profile data.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Profile',
      icon: Icons.badge_outlined,
      message: 'Profil, aktivitas, dan bookmark akan tersedia setelah login.',
    );
  }
}
