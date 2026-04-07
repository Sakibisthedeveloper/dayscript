import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/diary_entry.dart';
import '../bloc/diary/diary_bloc.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Good Day,', style: textTheme.headlineSmall?.copyWith(color: colors.outline)),
                    Text('Storyteller ✨', style: textTheme.displayMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    _buildWeeklyPulse(context),
                  ],
                ),
              ),
            ),
            BlocBuilder<DiaryBloc, DiaryState>(
              builder: (context, state) {
                if (state is DiaryLoaded) {
                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _EntryCard(entry: state.entries[index]),
                      childCount: state.entries.length,
                    ),
                  );
                }
                return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF3D3BF3),
        onPressed: () => context.push('/editor'),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildWeeklyPulse(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF3D3BF3).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3D3BF3).withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) => CircleAvatar(radius: 15, backgroundColor: Colors.white.withValues(alpha: 0.5), child: const Text('·'))),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final DiaryEntry entry;
  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(entry.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }
}