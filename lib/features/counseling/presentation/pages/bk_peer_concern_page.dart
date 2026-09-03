import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_spacing.dart';
import '../providers/peer_concern_providers.dart';

class BkPeerConcernPage extends ConsumerStatefulWidget {
  const BkPeerConcernPage({super.key});

  @override
  ConsumerState<BkPeerConcernPage> createState() => _BkPeerConcernPageState();
}

class _BkPeerConcernPageState extends ConsumerState<BkPeerConcernPage> {
  final _searchCtrl = TextEditingController();
  final _detailsCtrl = TextEditingController();
  String? _selectedRef;
  String? _selectedDisplay;
  String? _selectedReason;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _detailsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = _searchQuery.length >= 2 ? ref.watch(peerSearchProvider(_searchQuery)) : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Peduli Teman')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              child: const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text('Laporan ini hanya digunakan dalam layanan BK dan tidak ditampilkan di feed atau profil publik.\n\nGunakan fitur ini untuk menyampaikan kepedulian dengan jujur, bukan untuk menyerang atau mempermalukan teman.'),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(labelText: 'Cari pseudonim teman', hintText: 'Ketik minimal 2 karakter', border: OutlineInputBorder(), prefixIcon: Icon(Icons.search)),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (searchResults != null)
              searchResults.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Gagal mencari: ${e.toString().replaceAll('PeerConcernException: ', '')}'),
                data: (list) {
                  if (list.isEmpty) return const Text('Tidak ada teman ditemukan.');
                  return Column(
                    children: list
                        .map((p) => ListTile(
                              title: Text(p.displayPseudonym),
                              selected: _selectedRef == p.studentRef,
                              selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                              onTap: () => setState(() {
                                _selectedRef = p.studentRef;
                                _selectedDisplay = p.displayPseudonym;
                              }),
                              trailing: _selectedRef == p.studentRef ? const Icon(Icons.check) : null,
                            ))
                        .toList(),
                  );
                },
              ),
            if (_selectedDisplay != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Chip(label: Text('Dipilih: $_selectedDisplay'), onDeleted: () => setState(() => _selectedRef = null)),
            ],
            const SizedBox(height: AppSpacing.lg),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Alasan *', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'emotional', child: Text('Kondisi Emosional')),
                DropdownMenuItem(value: 'social', child: Text('Masalah Sosial')),
                DropdownMenuItem(value: 'academic', child: Text('Kesulitan Akademik')),
                DropdownMenuItem(value: 'family', child: Text('Masalah Keluarga')),
                DropdownMenuItem(value: 'bullying', child: Text('Perundungan')),
                DropdownMenuItem(value: 'safety_concern', child: Text('Kekhawatiran Keselamatan')),
                DropdownMenuItem(value: 'other', child: Text('Lainnya')),
              ],
              onChanged: (v) => setState(() => _selectedReason = v),
              validator: (v) => v == null ? 'Pilih alasan' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _detailsCtrl,
              decoration: const InputDecoration(labelText: 'Ceritakan apa yang membuatmu khawatir (opsional)', border: OutlineInputBorder()),
              maxLines: 4,
              maxLength: 2000,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  if (_selectedRef == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih teman terlebih dahulu.')));
                    return;
                  }
                  if (_selectedReason == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih alasan.')));
                    return;
                  }
                  final err = await ref.read(peerConcernControllerProvider.notifier).submit(targetRef: _selectedRef!, reason: _selectedReason!, details: _detailsCtrl.text.trim().isEmpty ? null : _detailsCtrl.text.trim());
                  if (err != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kepedulianmu sudah disampaikan kepada layanan BK.')));
                    Navigator.pop(context);
                  }
                },
                child: const Text('Sampaikan Kepedulian'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
