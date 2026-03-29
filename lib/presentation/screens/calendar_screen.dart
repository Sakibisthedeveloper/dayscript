import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../domain/entities/diary_entry.dart';
import '../bloc/diary/diary_bloc.dart';
import '../bloc/auth/auth_bloc.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  List<DiaryEntry> _getEventsForDay(DateTime day, List<DiaryEntry> entries) {
    return entries.where((entry) => isSameDay(entry.date, day)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is! Authenticated) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
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
          List<DiaryEntry> entries = [];
          if (state is DiaryLoaded) {
            entries = state.entries;
          }

          final eventsToday = _getEventsForDay(_selectedDay!, entries);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(color: colors.primary.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8))
                    ],
                  ),
                  child: TableCalendar<DiaryEntry>(
                    firstDay: DateTime.utc(2020, 10, 16),
                    lastDay: DateTime.utc(2030, 3, 14),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    eventLoader: (day) => _getEventsForDay(day, entries),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    calendarStyle: CalendarStyle(
                      markerDecoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
                      selectedDecoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
                      todayDecoration: BoxDecoration(color: colors.primaryContainer.withOpacity(0.5), shape: BoxShape.circle),
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: textTheme.titleLarge!.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text('Entries for ${_selectedDay?.day}/${_selectedDay?.month}', style: textTheme.titleLarge),
                const SizedBox(height: 16),
                ...eventsToday.map((entry) => ListTile(
                  title: Text(entry.title),
                  subtitle: Text(entry.content, maxLines: 1),
                  onTap: () => context.push('/entry', extra: entry),
                )),
                if (eventsToday.isEmpty)
                   const Text('No entries on this day.'),
              ],
            ),
          );
        },
      ),
    );
      },
    );
  }
}
