import 'package:image_picker/image_picker.dart';
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

class RemoveEntry extends DiaryEvent {
  final String userId;
  final DiaryEntry entry; // Changed to full entry
  const RemoveEntry(this.userId, this.entry);
  @override
  List<Object> get props => [userId, entry];
}

class UploadImageEvent extends DiaryEvent {
  final String userId;
  final XFile file;
  const UploadImageEvent(this.userId, this.file);
  @override
  List<Object> get props => [userId, file];
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
  const DiaryLoaded(this.entries, {this.hasReachedMax = false});
  @override
  List<Object?> get props => [entries, hasReachedMax];
}

class DiaryEntryOperationSuccess extends DiaryState {
  final String message;
  const DiaryEntryOperationSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class DiaryImageUploading extends DiaryState {}
class DiaryImageUploaded extends DiaryState {
  final String imageUrl;
  const DiaryImageUploaded(this.imageUrl);
  @override
  List<Object?> get props => [imageUrl];
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
  final UploadImage _uploadImage;

  DiaryBloc({
    required GetEntries getEntries,
    required SaveEntry saveEntry,
    required DeleteEntry deleteEntry,
    required UploadImage uploadImage,
  })  : _getEntries = getEntries,
        _saveEntry = saveEntry,
        _deleteEntry = deleteEntry,
        _uploadImage = uploadImage,
        super(DiaryInitial()) {
    on<LoadEntries>(_onLoadEntries);
    on<LoadMoreEntries>(_onLoadMoreEntries);
    on<AddOrUpdateEntry>(_onAddOrUpdateEntry);
    on<RemoveEntry>(_onRemoveEntry);
    on<UploadImageEvent>(_onUploadImage);
  }

  Future<void> _onLoadEntries(LoadEntries event, Emitter<DiaryState> emit) async {
    emit(DiaryLoading());
    try {
      final entries = await _getEntries(event.userId, limit: event.limit);
      emit(DiaryLoaded(entries, hasReachedMax: entries.length < event.limit));
    } catch (e) {
      emit(DiaryError(e.toString()));
    }
  }

  Future<void> _onLoadMoreEntries(LoadMoreEntries event, Emitter<DiaryState> emit) async {
    if (state is! DiaryLoaded || (state as DiaryLoaded).hasReachedMax) return;
    
    final currentEntries = (state as DiaryLoaded).entries;
    final lastEntryDate = currentEntries.last.date;

    try {
      final moreEntries = await _getEntries(event.userId, startAfter: lastEntryDate);
      if (moreEntries.isEmpty) {
        emit(DiaryLoaded(currentEntries, hasReachedMax: true));
      } else {
        emit(DiaryLoaded(currentEntries + moreEntries, hasReachedMax: moreEntries.length < 20));
      }
    } catch (e) {
      emit(DiaryError(e.toString()));
    }
  }

  Future<void> _onAddOrUpdateEntry(AddOrUpdateEntry event, Emitter<DiaryState> emit) async {
    try {
      await _saveEntry(event.userId, event.entry);
      emit(const DiaryEntryOperationSuccess('Entry saved successfully!'));
      add(LoadEntries(event.userId));
    } catch (e) {
      emit(DiaryError(e.toString()));
    }
  }

  Future<void> _onRemoveEntry(RemoveEntry event, Emitter<DiaryState> emit) async {
    try {
      await _deleteEntry(event.userId, event.entry);
      emit(const DiaryEntryOperationSuccess('Entry deleted successfully!'));
      add(LoadEntries(event.userId));
    } catch (e) {
      emit(DiaryError(e.toString()));
    }
  }

  Future<void> _onUploadImage(UploadImageEvent event, Emitter<DiaryState> emit) async {
    emit(DiaryImageUploading());
    try {
      final imageUrl = await _uploadImage(event.userId, event.file);
      emit(DiaryImageUploaded(imageUrl));
    } catch (e) {
      emit(DiaryError(e.toString()));
    }
  }
}

