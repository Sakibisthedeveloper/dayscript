import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/diary_entry.dart';
import '../bloc/diary/diary_bloc.dart';
import '../bloc/auth/auth_bloc.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _fabAnimationController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 0.8,
      upperBound: 1.0,
    )..value = 1.0;
  }

  void _onScroll() {
    if (_isBottom) {
      final authState = context.read<AuthBloc>().state;
      if (authState is Authenticated) {
        context.read<DiaryBloc>().add(LoadMoreEntries(authState.user.uid));
      }
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    final authState = context.read<AuthBloc>().state;
    if (authState is Authenticated) {
      context.read<DiaryBloc>().add(LoadEntries(authState.user.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! Authenticated) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final user = authState.user;

        return Scaffold(
          extendBody: true,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _onRefresh,
              color: colors.primary,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                  SliverAppBar(
                    floating: true,
                    backgroundColor: colors.surface.withOpacity(0.9),
                    title: Text('DayScript', style: textTheme.titleLarge?.copyWith(color: colors.primary, fontWeight: FontWeight.w800)),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: CircleAvatar(
                          backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                          backgroundColor: colors.primaryContainer,
                          child: user.photoURL == null ? const Icon(Icons.person, color: Colors.white) : null,
                        ),
                      )
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good ${DateTime.now().hour < 12 ? 'morning' : 'day'}, ${user.displayName?.split(' ').first ?? 'Friend'} ✨',
                            style: textTheme.displayMedium?.copyWith(height: 1.1),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            DateFormat('EEEE, MMMM d').format(DateTime.now()),
                            style: textTheme.titleMedium?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                  BlocBuilder<DiaryBloc, DiaryState>(
                    builder: (context, state) {
                      if (state is DiaryInitial || (state is DiaryLoading && state is! DiaryLoaded)) {
                        context.read<DiaryBloc>().add(LoadEntries(user.uid));
                        return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
                      } else if (state is DiaryLoaded) {
                        if (state.entries.isEmpty) {
                          return SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.auto_stories, size: 80, color: colors.primary.withOpacity(0.2)),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Your story begins here...',
                                    textAlign: TextAlign.center,
                                    style: textTheme.titleLarge?.copyWith(color: colors.outline),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tap the + button to write your first entry.',
                                    style: textTheme.bodyMedium?.copyWith(color: colors.outline),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index >= state.entries.length) {
                                  return state.hasReachedMax ? const SizedBox() : const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
                                }
                                final entry = state.entries[index];
                                return _buildEntryCard(context, entry);
                              },
                              childCount: state.entries.length + (state.hasReachedMax ? 0 : 1),
                            ),
                          ),
                        );
                      } else if (state is DiaryError) {
                        return SliverFillRemaining(child: Center(child: Text('Error: ${state.message}')));
                      }
                      return const SliverToBoxAdapter();
                    },
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
          floatingActionButton: ScaleTransition(
            scale: _fabAnimationController,
            child: FloatingActionButton(
              onPressed: () {
                _fabAnimationController.reverse().then((value) => _fabAnimationController.forward());
                context.push('/editor');
              },
              child: const Icon(Icons.add),
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: _buildBottomNav(context),
        );
      },
    );
  }

  Widget _buildEntryCard(BuildContext context, DiaryEntry entry) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => context.push('/entry', extra: entry),
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withOpacity(0.04),
              blurRadius: 32,
              offset: const Offset(0, 24),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors.tertiaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    entry.mood.toUpperCase(),
                    style: textTheme.labelSmall?.copyWith(
                      color: colors.onTertiaryContainer,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Text(
                  DateFormat('hh:mm a').format(entry.date),
                  style: textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              entry.title.isNotEmpty ? entry.title : 'Untitled',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              entry.content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
            ),
            if (entry.location != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: colors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(entry.location!, style: textTheme.labelMedium),
                ],
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.9),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withOpacity(0.05),
            blurRadius: 24,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: BottomNavigationBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.onSurfaceVariant,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Calendar'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
        ],
        onTap: (index) {
          if (index == 1) context.push('/calendar');
          if (index == 2) context.push('/search');
        },
      ),
    );
  }
}
