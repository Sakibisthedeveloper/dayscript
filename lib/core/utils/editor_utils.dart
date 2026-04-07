import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart';

class EditorUtils {
  /// Parses the content string and returns a Quill Document.
  /// If the content is plain text, it converts it to a basic Delta document automatically.
  static Document getDocument(String content) {
    if (content.isEmpty) {
      return Document();
    }

    try {
      final decoded = jsonDecode(content);
      return Document.fromJson(decoded);
    } catch (e) {
      // Not valid JSON, meaning it's old plain text.
      // Convert it to a basic Delta document.
      final doc = Document()..insert(0, content);
      return doc;
    }
  }

  /// Extracts the plain text snippet from the content.
  static String getPlainText(String content) {
    if (content.isEmpty) {
      return '';
    }

    try {
      final decoded = jsonDecode(content);
      final doc = Document.fromJson(decoded);
      return doc.toPlainText().trim();
    } catch (e) {
      // It's already plain text.
      return content.trim();
    }
  }
}
