import '../../domain/entities/diary_entry.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DiaryEntryModel extends DiaryEntry {
  const DiaryEntryModel({
    required String id,
    required String title,
    required String content,
    required DateTime date,
    required String mood,
    required List<String> photoUrls,
    required List<String> tags,
    String? location,
  }) : super(
          id: id,
          title: title,
          content: content,
          date: date,
          mood: mood,
          photoUrls: photoUrls,
          tags: tags,
          location: location,
        );

  factory DiaryEntryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DiaryEntryModel(
      id: doc.id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      mood: data['mood'] ?? 'Reflective',
      photoUrls: List<String>.from(data['photoUrls'] ?? []),
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
      'photoUrls': photoUrls,
      'tags': tags,
      'location': location,
    };
  }
}
