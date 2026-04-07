import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/diary_entry.dart';
import '../bloc/diary/diary_bloc.dart';
import '../bloc/auth/auth_bloc.dart';
class EditorScreen extends StatefulWidget {
  final DiaryEntry? entry;
  const EditorScreen({super.key, this.entry});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> with SingleTickerProviderStateMixin {
  late TextEditingController _titleController;
  late QuillController _quillController;
  late FocusNode _contentFocusNode;
  String _currentMood = 'Neutral';
  bool _isTyping = false;
  bool _showFormattingBar = false;
  Timer? _zenTimer;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry?.title ?? '');
    _currentMood = widget.entry?.mood ?? 'Neutral';

    Document doc;
    if (widget.entry != null) {
      try {
        doc = Document.fromJson(jsonDecode(widget.entry!.content));
      } catch (e) {
        doc = Document()..insert(0, widget.entry!.content);
      }
    } else {
      doc = Document();
    }

    _quillController = QuillController(document: doc, selection: const TextSelection.collapsed(offset: 0));
    _contentFocusNode = FocusNode();
    _quillController.addListener(_onContentChanged);
  }

  void _onContentChanged() {
    if (_contentFocusNode.hasFocus && !_isTyping) {
      setState(() => _isTyping = true);
    }
    _zenTimer?.cancel();
    _zenTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isTyping = false);
    });
  }

  @override
  void dispose() {
    _zenTimer?.cancel();
    _titleController.dispose();
    _quillController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  void _saveEntry() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    final entry = DiaryEntry(
      id: widget.entry?.id ?? const Uuid().v4(),
      title: _titleController.text,
      content: jsonEncode(_quillController.document.toDelta().toJson()),
      date: widget.entry?.date ?? DateTime.now(),
      mood: _currentMood,
      tags: const [],
    );

    context.read<DiaryBloc>().add(AddOrUpdateEntry(authState.user.uid, entry));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return BlocListener<DiaryBloc, DiaryState>(
      listener: (context, state) {
        if (state is DiaryEntryOperationSuccess) {
          HapticFeedback.mediumImpact();
          context.go('/home');
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FE),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: AnimatedOpacity(
            opacity: _isTyping ? 0.2 : 1.0,
            duration: const Duration(milliseconds: 300),
            child: AppBar(
              title: Text('DayScript', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
              actions: [IconButton(onPressed: _saveEntry, icon: const Icon(Icons.check))],
            ),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _titleController,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(hintText: 'Title...', border: InputBorder.none),
              ),
            ),
            _buildMoodRow(),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: QuillEditor.basic(
                  controller: _quillController,
                  focusNode: _contentFocusNode,
                ),
              ),
            ),
            if (_showFormattingBar)
              QuillSimpleToolbar(
                controller: _quillController,
              ),
            _buildBottomBar(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildMoodRow() {
    final moods = {'Happy': '😊', 'Calm': '😌', 'Neutral': '😐', 'Sad': '😔', 'Productive': '💪'};
    return AnimatedOpacity(
      opacity: _isTyping ? 0.2 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: moods.entries.map((e) => GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _currentMood = e.key);
          },
          child: Text(e.value, style: TextStyle(fontSize: _currentMood == e.key ? 35 : 25)),
        )).toList(),
      ),
    );
  }

  Widget _buildBottomBar(ColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.text_format, color: _showFormattingBar ? colors.primary : Colors.grey),
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _showFormattingBar = !_showFormattingBar);
            },
          ),
          const Spacer(),
          Text(DateFormat('MMMM d').format(DateTime.now()), style: GoogleFonts.plusJakartaSans(color: Colors.grey)),
        ],
      ),
    );
  }
}
