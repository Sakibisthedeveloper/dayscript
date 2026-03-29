import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/diary_entry.dart';
import '../bloc/diary/diary_bloc.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text('DayScript', style: textTheme.titleLarge?.copyWith(color: colors.primary, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocBuilder<DiaryBloc, DiaryState>(
        builder: (context, state) {
          if (state is! DiaryLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = state.entries;
          final filteredEntries = _query.isEmpty
              ? <DiaryEntry>[]
              : entries.where((e) {
                  return e.title.toLowerCase().contains(_query) ||
                         e.content.toLowerCase().contains(_query) ||
                         e.tags.any((tag) => tag.toLowerCase().contains(_query));
                }).toList();

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: colors.primary.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8))
                    ]
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      icon: Icon(Icons.search, color: colors.primary),
                      hintText: 'Search your memories...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                if (_query.isEmpty)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_stories, size: 72, color: colors.primary.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text('Search your memories...', style: textTheme.titleLarge),
                        Text('Find a moment, feeling, or date.', style: textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant)),
                      ],
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredEntries.length,
                      itemBuilder: (context, index) {
                        final entry = filteredEntries[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 0,
                          color: colors.surfaceContainerLow,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            title: Text(entry.title.isNotEmpty ? entry.title : 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(entry.content, maxLines: 2, overflow: TextOverflow.ellipsis),
                            trailing: Text(DateFormat('MMM d').format(entry.date)),
                            onTap: () => context.push('/entry', extra: entry),
                          ),
                        );
                      },
                    ),
                  )
              ],
            ),
          );
        },
      ),
    );
  }
}
