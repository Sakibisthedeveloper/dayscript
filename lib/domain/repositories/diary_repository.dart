import 'package:image_picker/image_picker.dart';
import '../entities/diary_entry.dart';

abstract class DiaryRepository {
  Future<List<DiaryEntry>> getEntries(String userId, {int limit, dynamic startAfter});
  Future<DiaryEntry> getEntryById(String userId, String entryId);
  Future<void> saveEntry(String userId, DiaryEntry entry);
  Future<void> deleteEntry(String userId, DiaryEntry entry); // Changed to take full entry to get photoUrls
  Future<String> uploadImage(String userId, XFile imageFile);
}
