import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_page.dart';

/// Explore tab. M0 placeholder — no search, subjects, or topics yet.
class ExplorePage extends StatelessWidget {
  const ExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Explore',
      icon: Icons.travel_explore_outlined,
      message: 'Pencarian materi, mata pelajaran, dan topik akan hadir di sini.',
    );
  }
}
