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
    final rawMood = data['mood']?.toString().toLowerCase() ?? '';
    final validMoods = {'productive', 'happy', 'calm', 'neutral', 'sad'};
    final mood = validMoods.contains(rawMood) ? rawMood : 'neutral';

    return DiaryEntryModel(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      mood: mood,
      tags: List<String>.from(data['tags'] ?? []),
      location: data['location'],
    );
  }

  Map<String, dynamic> toFirestore() {
    final validMoods = {'productive', 'happy', 'calm', 'neutral', 'sad'};
    final standardizedMood = validMoods.contains(mood.toLowerCase()) ? mood.toLowerCase() : 'neutral';

    return {
      'title': title,
      'content': content,
      'date': Timestamp.fromDate(date),
      'mood': standardizedMood,
      'tags': tags,
      'location': location,
    };
  }
}
