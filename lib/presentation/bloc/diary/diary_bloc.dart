import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../domain/entities/diary_entry.dart';
import '../../../domain/usecases/diary_usecases.dart';

// Events
abstract class DiaryEvent extends Equatable {
  const DiaryEvent();
  @override
  List<Object> get props => [];
}

class LoadEntries extends DiaryEvent {
  final String userId;
  final int limit;
  const LoadEntries(this.userId, {this.limit = 20});
  @override
  List<Object> get props => [userId, limit];
}

class LoadMoreEntries extends DiaryEvent {
  final String userId;
  const LoadMoreEntries(this.userId);
  @override
  List<Object> get props => [userId];
}

class AddOrUpdateEntry extends DiaryEvent {
  final String userId;
  final DiaryEntry entry;
  const AddOrUpdateEntry(this.userId, this.entry);
  @override
  List<Object> get props => [userId, entry];
}

class AutoSaveEntry extends DiaryEvent {
  final String userId;
  final DiaryEntry entry;
  const AutoSaveEntry(this.userId, this.entry);
  @override
  List<Object> get props => [userId, entry];
}

class RemoveEntry extends DiaryEvent {
  final String userId;
  final DiaryEntry entry; // Changed to full entry
  const RemoveEntry(this.userId, this.entry);
  @override
  List<Object> get props => [userId, entry];
}

// States
abstract class DiaryState extends Equatable {
  const DiaryState();
  @override
  List<Object?> get props => [];
}

class DiaryInitial extends DiaryState {}
class DiaryLoading extends DiaryState {}
class DiaryLoaded extends DiaryState {
  final List<DiaryEntry> entries;
  final bool hasReachedMax;
  final Map<DateTime, String?> weeklyMoods;

  const DiaryLoaded(
    this.entries, {
    this.hasReachedMax = false,
    this.weeklyMoods = const {},
  });

  @override
  List<Object?> get props => [entries, hasReachedMax, weeklyMoods];
}

class DiaryEntryOperationSuccess extends DiaryState {
  final String message;
  const DiaryEntryOperationSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class DiaryError extends DiaryState {
  final String message;
  const DiaryError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class DiaryBloc extends Bloc<DiaryEvent, DiaryState> {
  final GetEntries _getEntries;
  final SaveEntry _saveEntry;
  final DeleteEntry _deleteEntry;
  final GetWeeklyPulse _getWeeklyPulse;
  bool _isLoadingMore = false; // Fix 2: guard against concurrent loads

  DiaryBloc({
    required GetEntries getEntries,
    required SaveEntry saveEntry,
    required DeleteEntry deleteEntry,
    required GetWeeklyPulse getWeeklyPulse,
  })  : _getEntries = getEntries,
        _saveEntry = saveEntry,
        _deleteEntry = deleteEntry,
        _getWeeklyPulse = getWeeklyPulse,
        super(DiaryInitial()) {
    on<LoadEntries>(_onLoadEntries);
    on<LoadMoreEntries>(_onLoadMoreEntries);
    on<AddOrUpdateEntry>(_onAddOrUpdateEntry);
    on<AutoSaveEntry>(_onAutoSaveEntry);
    on<RemoveEntry>(_onRemoveEntry);
  }

  Future<void> _onLoadEntries(LoadEntries event, Emitter<DiaryState> emit) async {
    emit(DiaryLoading());
    try {
      final entries = await _getEntries(event.userId, limit: event.limit);
      final weeklyMoods = await _getWeeklyPulse(event.userId);
      emit(DiaryLoaded(entries, hasReachedMax: entries.length < event.limit, weeklyMoods: weeklyMoods));
    } catch (e) {
      emit(DiaryError(e.toString()));
    }
  }

  Future<void> _onLoadMoreEntries(LoadMoreEntries event, Emitter<DiaryState> emit) async {
    if (state is! DiaryLoaded || (state as DiaryLoaded).hasReachedMax) return;
    if (_isLoadingMore) return; // Fix 2: prevent concurrent loads
    _isLoadingMore = true;

    final currentState = state as DiaryLoaded;
    final currentEntries = currentState.entries;
    final lastEntryDate = currentEntries.last.date;
    final weeklyMoods = currentState.weeklyMoods;

    try {
      final moreEntries = await _getEntries(event.userId, startAfter: lastEntryDate);
      if (moreEntries.isEmpty) {
        emit(DiaryLoaded(currentEntries, hasReachedMax: true, weeklyMoods: weeklyMoods));
      } else {
        emit(DiaryLoaded(currentEntries + moreEntries, hasReachedMax: moreEntries.length < 20, weeklyMoods: weeklyMoods));
      }
    } catch (e) {
      emit(DiaryError(e.toString()));
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> _onAddOrUpdateEntry(AddOrUpdateEntry event, Emitter<DiaryState> emit) async {
    List<DiaryEntry> oldEntries = [];
    bool reachedMax = false;
    Map<DateTime, String?> weeklyMoods = {};
    List<DiaryEntry>? optimEntries;
    
    if (state is DiaryLoaded) {
      final currentState = state as DiaryLoaded;
      oldEntries = currentState.entries;
      reachedMax = currentState.hasReachedMax;
      weeklyMoods = currentState.weeklyMoods;
      
      optimEntries = List.from(oldEntries);
      final index = optimEntries.indexWhere((e) => e.id == event.entry.id);
      if (index >= 0) {
        optimEntries[index] = event.entry;
      } else {
        optimEntries.insert(0, event.entry);
        optimEntries.sort((a,b) => b.date.compareTo(a.date));
      }
      emit(DiaryLoaded(optimEntries, hasReachedMax: reachedMax, weeklyMoods: weeklyMoods));
    }

    try {
      await _saveEntry(event.userId, event.entry);
      // Re-fetch weekly pulse after save to ensure it's up to date
      final updatedWeeklyMoods = await _getWeeklyPulse(event.userId);

      emit(const DiaryEntryOperationSuccess('Entry saved successfully!'));
      if (optimEntries != null) emit(DiaryLoaded(optimEntries, hasReachedMax: reachedMax, weeklyMoods: updatedWeeklyMoods));
    } catch (e) {
      if (oldEntries.isNotEmpty) emit(DiaryLoaded(oldEntries, hasReachedMax: reachedMax, weeklyMoods: weeklyMoods));
      emit(DiaryError(e.toString()));
    }
  }

  Future<void> _onAutoSaveEntry(AutoSaveEntry event, Emitter<DiaryState> emit) async {
    // Silent background save
    try {
      await _saveEntry(event.userId, event.entry);
    } catch (_) {}
  }

  Future<void> _onRemoveEntry(RemoveEntry event, Emitter<DiaryState> emit) async {
    List<DiaryEntry> oldEntries = [];
    bool reachedMax = false;
    Map<DateTime, String?> weeklyMoods = {};
    List<DiaryEntry>? optimEntries;
    
    if (state is DiaryLoaded) {
      final currentState = state as DiaryLoaded;
      oldEntries = currentState.entries;
      reachedMax = currentState.hasReachedMax;
      weeklyMoods = currentState.weeklyMoods;
      
      optimEntries = List.from(oldEntries)..removeWhere((e) => e.id == event.entry.id);
      emit(DiaryLoaded(optimEntries, hasReachedMax: reachedMax, weeklyMoods: weeklyMoods));
    }

    try {
      await _deleteEntry(event.userId, event.entry);
      // Re-fetch weekly pulse after delete to ensure it's up to date
      final updatedWeeklyMoods = await _getWeeklyPulse(event.userId);

      emit(const DiaryEntryOperationSuccess('Entry deleted successfully!'));
      if (optimEntries != null) emit(DiaryLoaded(optimEntries, hasReachedMax: reachedMax, weeklyMoods: updatedWeeklyMoods));
    } catch (e) {
      if (oldEntries.isNotEmpty) emit(DiaryLoaded(oldEntries, hasReachedMax: reachedMax, weeklyMoods: weeklyMoods));
      emit(DiaryError(e.toString()));
    }
  }

}

