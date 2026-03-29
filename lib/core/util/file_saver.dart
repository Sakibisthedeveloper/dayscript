import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

// We avoid direct dart:io imports to ensure web compatibility.
// For mobile specific logic we will use conditional checks.
import 'dart:async';

class FileSaver {
  static Future<void> savePdf({
    required String fileName,
    required Uint8List bytes,
  }) async {
    // Printing package handles web/mobile correctly
    await Printing.sharePdf(bytes: bytes, filename: fileName);
  }

  static Future<void> saveJson({
    required String fileName,
    required List<Map<String, dynamic>> data,
  }) async {
    final jsonString = jsonEncode(data);
    final bytes = Uint8List.fromList(utf8.encode(jsonString));
    
    if (kIsWeb) {
      // Use printing to share (triggers browser download if implemented)
      // or we can use a small web-only helper if needed.
      // Printing.sharePdf usually works for generic bytes too.
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    } else {
      // Use share_plus with XFile.fromData
      await Share.shareXFiles(
        [XFile.fromData(bytes, name: fileName, mimeType: 'application/json')],
        text: 'Exported JSON',
      );
    }
  }
}
