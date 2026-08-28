import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_page.dart';

/// Home feed tab. M0 placeholder — no feed data, no posting.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Edufess',
      icon: Icons.menu_book_outlined,
      message: 'Feed catatan, rangkuman, dan diskusi akan muncul di sini.',
    );
  }
}
