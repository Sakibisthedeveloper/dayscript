import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/diary_entry.dart';
import '../../domain/repositories/diary_repository.dart';
import '../models/diary_entry_model.dart';

class FirebaseDiaryRepository implements DiaryRepository {
  final FirebaseFirestore _firestore;

  FirebaseDiaryRepository({
    FirebaseFirestore? firestore,
  })  : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference _getCollection(String userId) {
    return _firestore.collection('users').doc(userId).collection('entries');
  }

  @override
  Future<List<DiaryEntry>> getEntries(String userId, {int limit = 20, dynamic startAfter}) async {
    try {
      var query = _getCollection(userId).orderBy('date', descending: true).limit(limit);

      if (startAfter != null) {
        query = query.startAfter([startAfter]);
      }

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => DiaryEntryModel.fromFirestore(doc)).toList();
    } catch (e) {
      throw Exception('Failed to get entries: $e');
    }
  }

  @override
  Future<DiaryEntry> getEntryById(String userId, String entryId) async {
    try {
      final doc = await _getCollection(userId).doc(entryId).get();
      if (!doc.exists) {
        throw Exception('Entry not found');
      }
      return DiaryEntryModel.fromFirestore(doc);
    } catch (e) {
      throw Exception('Failed to get entry: $e');
    }
  }

  @override
  Future<void> saveEntry(String userId, DiaryEntry entry) async {
    try {
      final model = DiaryEntryModel(
        id: entry.id,
        title: entry.title,
        content: entry.content,
        date: entry.date,
        mood: entry.mood,
        tags: entry.tags,
        location: entry.location,
      );

      if (entry.id.isEmpty) {
        await _getCollection(userId).add(model.toFirestore());
      } else {
        await _getCollection(userId).doc(entry.id).set(model.toFirestore(), SetOptions(merge: true));
      }
    } catch (e) {
      throw Exception('Failed to save entry: $e');
    }
  }

  @override
  Future<void> deleteEntry(String userId, DiaryEntry entry) async {
    try {
      await _getCollection(userId).doc(entry.id).delete();
    } catch (e) {
      throw Exception('Failed to delete entry: $e');
    }
  }

  @override
  Future<Map<DateTime, String?>> getWeeklyPulse(String userId) async {
    try {
      final now = DateTime.now();
      // Normalize to start of today
      final today = DateTime(now.year, now.month, now.day);
      final sevenDaysAgo = today.subtract(const Duration(days: 6)); // Today + 6 previous days = 7 days

      final snapshot = await _getCollection(userId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
          .orderBy('date', descending: true)
          .get();

      final entries = snapshot.docs.map((doc) => DiaryEntryModel.fromFirestore(doc)).toList();

      final validMoods = {'productive', 'happy', 'calm', 'neutral', 'sad'};

      final pulse = <DateTime, String?>{};
      for (int i = 0; i < 7; i++) {
        final currentDay = today.subtract(Duration(days: i));

        // Find an entry for this specific day
        final entryForDay = entries.where((e) =>
            e.date.year == currentDay.year &&
            e.date.month == currentDay.month &&
            e.date.day == currentDay.day).firstOrNull;

        if (entryForDay != null) {
          final mood = entryForDay.mood.toLowerCase();
          pulse[currentDay] = validMoods.contains(mood) ? mood : 'neutral';
        } else {
          pulse[currentDay] = null;
        }
      }

      return pulse;
    } catch (e) {
      throw Exception('Failed to get weekly pulse: $e');
    }
  }

}
