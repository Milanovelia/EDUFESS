import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_page.dart';

/// BK (counseling) tab. M0 placeholder.
///
/// Privacy invariant: counseling data must never surface in the public feed,
/// and nothing here may diagnose a student.
class BkPage extends StatelessWidget {
  const BkPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'BK Support',
      icon: Icons.health_and_safety_outlined,
      message: 'Ruang privat untuk dukungan siswa. Terpisah dari feed publik.',
    );
  }
}
