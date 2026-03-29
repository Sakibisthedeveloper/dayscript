import 'package:equatable/equatable.dart';

class DiaryEntry extends Equatable {
  final String id;
  final String title;
  final String content;
  final DateTime date;
  final String mood;
  final List<String> photoUrls;
  final List<String> tags;
  final String? location;

  const DiaryEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.date,
    required this.mood,
    required this.photoUrls,
    required this.tags,
    this.location,
  });

  DiaryEntry copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? date,
    String? mood,
    List<String>? photoUrls,
    List<String>? tags,
    String? location,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      date: date ?? this.date,
      mood: mood ?? this.mood,
      photoUrls: photoUrls ?? this.photoUrls,
      tags: tags ?? this.tags,
      location: location ?? this.location,
    );
  }

  @override
  List<Object?> get props => [id, title, content, date, mood, photoUrls, tags, location];
}
