import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/diary_entry.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/diary/diary_bloc.dart';
import '../bloc/auth/auth_bloc.dart';

class ViewEntryScreen extends StatelessWidget {
  final DiaryEntry entry;

  const ViewEntryScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('DayScript', style: textTheme.titleLarge?.copyWith(color: colors.primary, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/editor', extra: entry),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final authState = context.read<AuthBloc>().state;
              if (authState is! Authenticated) return;

              final bool? confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Entry?'),
                  content: const Text('This action cannot be undone and will also delete associated photos.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text('Delete', style: TextStyle(color: colors.error)),
                    ),
                  ],
                ),
              );

              if (confirm ?? false) {
                if (context.mounted) {
                  context.read<DiaryBloc>().add(RemoveEntry(authState.user.uid, entry));
                  context.pop();
                }
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.mood, size: 14, color: colors.onSecondaryContainer),
                      const SizedBox(width: 4),
                      Text(entry.mood, style: textTheme.labelSmall?.copyWith(color: colors.onSecondaryContainer, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const Spacer(),
                Text('5 min read', style: textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              entry.title.isNotEmpty ? entry.title : 'Untitled',
              style: textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.1),
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat('EEEE, MMMM d, yyyy • h:mm a').format(entry.date),
              style: textTheme.titleMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: colors.primary.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 4))
                ],
              ),
              child: Text(
                entry.content,
                style: textTheme.titleMedium?.copyWith(height: 1.7, fontWeight: FontWeight.normal),
              ),
            ),
            // Photo Grid Section (Asymmetric Bento Style)
            if (entry.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 32),
              Text(
                'CAPTURED MOMENTS',
                style: textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              StaggeredGrid.count(
                crossAxisCount: 12,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  // Main Large Image
                  if (entry.photoUrls.isNotEmpty)
                    StaggeredGridTile.count(
                      crossAxisCellCount: 8,
                      mainAxisCellCount: 8,
                      child: _buildGridImage(entry.photoUrls[0]),
                    ),
                  // Smaller images
                  if (entry.photoUrls.length > 1)
                    StaggeredGridTile.count(
                      crossAxisCellCount: 4,
                      mainAxisCellCount: 4,
                      child: _buildGridImage(entry.photoUrls[1]),
                    ),
                  if (entry.photoUrls.length > 2)
                    StaggeredGridTile.count(
                      crossAxisCellCount: 4,
                      mainAxisCellCount: 4,
                      child: _buildGridImage(entry.photoUrls[2]),
                    ),
                ],
              ),
            ],
            // Tags
            if (entry.tags.isNotEmpty) ...[
              const SizedBox(height: 32),
              Wrap(
                spacing: 8,
                children: entry.tags.map((tag) => Chip(
                  label: Text('#$tag'),
                  backgroundColor: colors.surfaceContainerHigh,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                )).toList(),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildGridImage(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Image.network(
        url,
        fit: BoxFit.cover,
      ),
    );
  }
}
