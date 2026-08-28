import 'package:flutter/material.dart';

import '../../../../core/widgets/placeholder_page.dart';

/// Create tab. M0 placeholder — no posting form or draft logic.
class CreatePostPage extends StatelessWidget {
  const CreatePostPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'Create',
      icon: Icons.edit_note_outlined,
      message: 'Tempat berbagi catatan, tips, atau pertanyaan akademik.',
    );
  }
}
