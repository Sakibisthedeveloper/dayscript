import 'package:image_picker/image_picker.dart';
import '../entities/diary_entry.dart';
import '../repositories/diary_repository.dart';

class GetEntries {
  final DiaryRepository repository;
  GetEntries(this.repository);

  Future<List<DiaryEntry>> call(String userId, {int limit = 20, dynamic startAfter}) async {
    return await repository.getEntries(userId, limit: limit, startAfter: startAfter);
  }
}

class SaveEntry {
  final DiaryRepository repository;
  SaveEntry(this.repository);

  Future<void> call(String userId, DiaryEntry entry) async {
    await repository.saveEntry(userId, entry);
  }
}

class DeleteEntry {
  final DiaryRepository repository;
  DeleteEntry(this.repository);

  Future<void> call(String userId, DiaryEntry entry) async {
    await repository.deleteEntry(userId, entry);
  }
}

class UploadImage {
  final DiaryRepository repository;
  UploadImage(this.repository);

  Future<String> call(String userId, XFile imageFile) async {
    return await repository.uploadImage(userId, imageFile);
  }
}
