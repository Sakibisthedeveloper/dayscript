import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../domain/entities/diary_entry.dart';
import '../../domain/repositories/diary_repository.dart';
import '../models/diary_entry_model.dart';

class FirebaseDiaryRepository implements DiaryRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  FirebaseDiaryRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

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
        photoUrls: entry.photoUrls,
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

      for (final url in entry.photoUrls) {
        try {
          final ref = _storage.refFromURL(url);
          await ref.delete();
        } catch (_) {
          // Silent: best-effort cleanup of storage files
        }
      }
    } catch (e) {
      throw Exception('Failed to delete entry: $e');
    }
  }

  @override
  Future<String> uploadImage(String userId, XFile imageFile) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '$timestamp.jpg';
      // Path: users/{userId}/images/{timestamp}.jpg
      final ref = _storage
          .ref()
          .child('users')
          .child(userId)
          .child('images')
          .child(fileName);

      final bytes = await imageFile.readAsBytes();
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {'uploadedBy': userId},
      );

      final uploadTask = ref.putData(bytes, metadata);

      // Listen to task state for better error reporting
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        // Progress available if needed in the future
      }, onError: (_) {});

      final snapshot = await uploadTask;

      if (snapshot.state != TaskState.success) {
        throw Exception('Upload did not complete successfully (state: ${snapshot.state})');
      }

      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      // Surface the real Firebase error code & message
      throw Exception('[${e.code}] ${e.message ?? 'Firebase Storage error'}');
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }
}
