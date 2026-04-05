import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
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
      // 1. Delete document from Firestore
      await _getCollection(userId).doc(entry.id).delete();

      // 2. Delete associated photos from Storage
      for (final url in entry.photoUrls) {
        try {
          final ref = _storage.refFromURL(url);
          await ref.delete();
        } catch (e) {
          // Silent error handling for storage deletion
        }
      }
    } catch (e) {
      throw Exception('Failed to delete entry: $e');
    }
  }

  @override
  Future<String> uploadImage(String userId, XFile imageFile) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child('users/$userId/images/$fileName');
      
      final SettableMetadata metadata = SettableMetadata(contentType: 'image/jpeg');

      // Using putData with bytes is cross-platform compatible
      final bytes = await imageFile.readAsBytes();
      final uploadTask = await ref.putData(bytes, metadata);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }
}
