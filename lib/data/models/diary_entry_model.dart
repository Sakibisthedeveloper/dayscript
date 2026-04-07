import '../../domain/entities/diary_entry.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DiaryEntryModel extends DiaryEntry {
  const DiaryEntryModel({
    required super.id,
    required super.title,
    required super.content,
    required super.date,
    required super.mood,
    required super.tags,
    super.location,
  });

  factory DiaryEntryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DiaryEntryModel(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      mood: data['mood'] ?? 'Reflective',
      tags: List<String>.from(data['tags'] ?? []),
      location: data['location'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'content': content,
      'date': Timestamp.fromDate(date),
      'mood': mood,
      'tags': tags,
      'location': location,
    };
  }
}
