import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../core/util/file_saver.dart';

import '../bloc/diary/diary_bloc.dart';
import '../../data/models/diary_entry_model.dart';
import '../../domain/entities/diary_entry.dart';

class ExportScreen extends StatelessWidget {
  const ExportScreen({super.key});

  Future<void> _exportAsJson(BuildContext context, List<DiaryEntry> entries) async {
    try {
      final List<Map<String, dynamic>> jsonList = entries.map((e) {
        return DiaryEntryModel(
          id: e.id,
          title: e.title,
          content: e.content,
          date: e.date,
          mood: e.mood,
          photoUrls: e.photoUrls,
          tags: e.tags,
          location: e.location,
        ).toFirestore();
      }).toList();

      for (var map in jsonList) {
        map['date'] = (map['date']).toDate().toIso8601String();
      }

      await FileSaver.saveJson(
        fileName: 'dayscript_export.json',
        data: jsonList,
      );
      if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('JSON export successful!')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export as JSON: $e')));
      }
    }
  }

  Future<void> _exportAsPdf(BuildContext context, List<DiaryEntry> entries) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Header(level: 0, child: pw.Text("DayScript Diary Export", style: const pw.TextStyle(fontSize: 24))),
              pw.SizedBox(height: 20),
              ...entries.map((e) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(e.title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text("${e.date.toString()} - Mood: ${e.mood}", style: const pw.TextStyle(color: PdfColors.grey700)),
                  pw.SizedBox(height: 10),
                  pw.Text(e.content),
                  pw.Divider(),
                  pw.SizedBox(height: 10),
                ]
              )),
            ];
          },
        ),
      );

      await FileSaver.savePdf(
        fileName: 'dayscript_export.pdf',
        bytes: await pdf.save(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF export successful!')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to export as PDF: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Export', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: BlocBuilder<DiaryBloc, DiaryState>(
        builder: (context, state) {
          if (state is! DiaryLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = state.entries;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.cloud_download, size: 80, color: colors.primary),
                const SizedBox(height: 24),
                Text('Export your journey', style: textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                Text('Download all your diary entries safely to your device.', textAlign: TextAlign.center, style: textTheme.titleMedium),
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildExportOption(
                      context, title: 'Export PDF', icon: Icons.picture_as_pdf, 
                      onTap: () => _exportAsPdf(context, entries)
                    ),
                    _buildExportOption(
                      context, title: 'Export JSON', icon: Icons.data_object, 
                      onTap: () => _exportAsJson(context, entries)
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildExportOption(BuildContext context, {required String title, required IconData icon, required VoidCallback onTap}) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineVariant.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(color: colors.primary.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8))
          ]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: colors.primaryContainer.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 32, color: colors.primary),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
