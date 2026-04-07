import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as material show Text;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
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
  String _currentMood = 'Reflective';
  Timer? _autoSaveTimer;
  Timer? _zenTimer; // Timer for Zen Mode fade back
  bool _isTyping = false;
  bool _showFormattingBar = false;
  late AnimationController _formattingBarController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry?.title ?? '');

    // Initialize Quill Controller
    Document doc;
    if (widget.entry != null) {
      try {
        final contentJson = jsonDecode(widget.entry!.content);
        doc = Document.fromJson(contentJson);
      } catch (e) {
        // Fallback for plain text entries
        doc = Document()..insert(0, widget.entry!.content);
      }
    } else {
      doc = Document();
    }

    _quillController = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );

    _contentFocusNode = FocusNode();

    _quillController.addListener(_onContentChanged);
    _contentFocusNode.addListener(_onFocusChanged);

    if (widget.entry != null) {
      _currentMood = widget.entry!.mood;
    }

    _formattingBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 1.2), // Start slightly below
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _formattingBarController,
      curve: Curves.easeOutBack, // Playful bounce
    ));

    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_hasChanges()) _autoSaveEntry();
    });
  }

  void _onContentChanged() {
    // Detect typing for Zen Mode
    if (_contentFocusNode.hasFocus && !_isTyping) {
      setState(() => _isTyping = true);
    }

    // Reset zen timer
    _zenTimer?.cancel();
    _zenTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isTyping) {
        setState(() => _isTyping = false);
      }
    });

    // Detect selection for Formatting Bar
    final hasSelection = !_quillController.selection.isCollapsed;
    if (hasSelection && !_showFormattingBar) {
       _updateFormattingBarVisibility(true);
    } else if (!hasSelection && _showFormattingBar && !_manualFormattingToggle) {
       _updateFormattingBarVisibility(false);
    }
  }

  void _updateFormattingBarVisibility(bool visible) {
    if (visible) {
      setState(() => _showFormattingBar = true);
      _formattingBarController.forward();
    } else {
      _formattingBarController.reverse().then((_) {
        if (mounted && !_manualFormattingToggle && _quillController.selection.isCollapsed) {
          setState(() => _showFormattingBar = false);
        }
      });
    }
  }

  bool _manualFormattingToggle = false;

  void _onFocusChanged() {
    if (!_contentFocusNode.hasFocus) {
      setState(() => _isTyping = false);
      if (!_manualFormattingToggle) {
        _updateFormattingBarVisibility(false);
      }
    }
  }

  void _toggleFormattingBar() {
    setState(() {
      _manualFormattingToggle = !_manualFormattingToggle || !_showFormattingBar;
      if (!_showFormattingBar) {
        _updateFormattingBarVisibility(true);
      } else if (!_manualFormattingToggle) {
        _updateFormattingBarVisibility(false);
      }
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _zenTimer?.cancel();
    _formattingBarController.dispose();
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
      tags: widget.entry?.tags ?? [],
      location: widget.entry?.location,
    );

    context.read<DiaryBloc>().add(AddOrUpdateEntry(authState.user.uid, entry));
  }

  void _autoSaveEntry() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    final entry = DiaryEntry(
      id: widget.entry?.id ?? const Uuid().v4(),
      title: _titleController.text,
      content: jsonEncode(_quillController.document.toDelta().toJson()),
      date: widget.entry?.date ?? DateTime.now(),
      mood: _currentMood,
      tags: widget.entry?.tags ?? [],
      location: widget.entry?.location,
    );

    context.read<DiaryBloc>().add(AutoSaveEntry(authState.user.uid, entry));
  }

  bool _hasChanges() {
    final originalTitle = widget.entry?.title ?? '';
    final currentContent = jsonEncode(_quillController.document.toDelta().toJson());
    final originalContent = widget.entry?.content ?? '';
    final originalMood = widget.entry?.mood ?? 'Reflective';
    return _titleController.text != originalTitle ||
        currentContent != originalContent ||
        _currentMood != originalMood;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isNew = widget.entry == null;

    return BlocListener<DiaryBloc, DiaryState>(
      listenWhen: (previous, current) =>
          current is DiaryEntryOperationSuccess ||
          current is DiaryError,
      listener: (context, state) async {
        if (state is DiaryEntryOperationSuccess) {
          HapticFeedback.mediumImpact();
          await Future.delayed(const Duration(milliseconds: 100));
          HapticFeedback.lightImpact();

          if (context.mounted) {
            context.go('/home');
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  material.Text('Entry saved! ✓', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
                ],
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: colors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ));
          }
        } else if (state is DiaryError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: material.Text(state.message), backgroundColor: colors.error),
          );
        }
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          if (!_hasChanges()) {
            context.pop();
            return;
          }
          final bool? shouldPop = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const material.Text('Discard changes?'),
              content: const material.Text('You have unsaved changes. Are you sure you want to leave?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const material.Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: material.Text('Discard', style: TextStyle(color: colors.error)),
                ),
              ],
            ),
          );
          if (shouldPop ?? false) {
            if (context.mounted) context.pop();
          }
        },
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            extendBody: true,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: _isTyping ? 0.2 : 1.0,
                child: AppBar(
                  backgroundColor: colors.surface.withValues(alpha: 0.9),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      material.Text(
                        isNew ? 'New Entry' : 'Edit Entry',
                        style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      material.Text(
                        DateFormat('MMMM d, yyyy').format(widget.entry?.date ?? DateTime.now()),
                        style: textTheme.labelSmall,
                      ),
                    ],
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: ElevatedButton(
                        onPressed: _saveEntry,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: colors.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const material.Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            body: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24.0,
                right: 24.0,
                top: 24.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 120.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    style: textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Title your day...',
                      hintStyle: textTheme.displayMedium?.copyWith(color: colors.outlineVariant),
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Animated Mood Section with Glassmorphism
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: _isTyping ? 0.2 : 1.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.mood, color: colors.primary, size: 20),
                            const SizedBox(width: 8),
                            material.Text(
                              'This moment feels...',
                              style: textTheme.labelMedium?.copyWith(
                                color: colors.onSurface.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _MoodEmojiRow(
                          selectedMood: _currentMood,
                          onSelected: (mood) {
                            HapticFeedback.lightImpact();
                            setState(() => _currentMood = mood);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Rich Text Editor with Zen Writing Background
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FF), // Soft Indigo Grey
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: QuillEditor.basic(
                      controller: _quillController,
                      focusNode: _contentFocusNode,
                    ),
                  ),
                ],
              ),
            ),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
            floatingActionButton: _showFormattingBar
                ? Padding(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 0 : 80),
                    child: SlideTransition(
                        position: _slideAnimation,
                        child: _FloatingIndigoToolbar(
                          controller: _quillController,
                        ),
                      ),
                  )
                : null,
            bottomNavigationBar: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  boxShadow: [
                    BoxShadow(
                      color: colors.primary.withValues(alpha: 0.12),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildToolButton(Icons.text_format, 'Format', colors, onTap: () {
                      HapticFeedback.selectionClick();
                      _toggleFormattingBar();
                    }),
                    Container(width: 1, height: 32, color: colors.outlineVariant.withValues(alpha: 0.2)),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: colors.primaryContainer.withValues(alpha: 0.2),
                        foregroundColor: colors.primary,
                        minimumSize: const Size(48, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.check_circle_outline),
                      onPressed: _saveEntry,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolButton(IconData icon, String label, ColorScheme colors, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colors.primary, size: 24),
            const SizedBox(width: 12),
            material.Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: colors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoodOption {
  final String label;
  final String emoji;
  const _MoodOption(this.label, this.emoji);
}

const List<_MoodOption> _moods = [
  _MoodOption('Happy', '😊'),
  _MoodOption('Calm', '😌'),
  _MoodOption('Neutral', '😐'),
  _MoodOption('Sad', '😔'),
  _MoodOption('Productive', '💪'),
];

class _MoodEmojiRow extends StatelessWidget {
  final String selectedMood;
  final Function(String) onSelected;

  const _MoodEmojiRow({required this.selectedMood, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _moods.map((mood) {
          final isSelected = selectedMood == mood.label;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _MoodEmoji(
              mood: mood,
              isSelected: isSelected,
              onTap: () => onSelected(mood.label),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MoodEmoji extends StatefulWidget {
  final _MoodOption mood;
  final bool isSelected;
  final VoidCallback onTap;

  const _MoodEmoji({
    required this.mood,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_MoodEmoji> createState() => _MoodEmojiState();
}

class _MoodEmojiState extends State<_MoodEmoji> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    if (widget.isSelected) _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(_MoodEmoji oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected != oldWidget.isSelected) {
      if (widget.isSelected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        children: [
          ScaleTransition(
            scale: _scaleAnimation,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glassmorphic Background for Selected State
                if (widget.isSelected)
                  ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3D3BF3).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: widget.isSelected ? Colors.white.withValues(alpha: 0.2) : colors.surfaceContainerLow,
                    shape: BoxShape.circle,
                    boxShadow: widget.isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF3D3BF3).withValues(alpha: 0.3),
                              blurRadius: 15,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            )
                          ]
                        : null,
                    border: Border.all(
                      color: widget.isSelected ? const Color(0xFF3D3BF3).withValues(alpha: 0.5) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: material.Text(
                      widget.mood.emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          material.Text(
            widget.mood.label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w500,
              color: widget.isSelected ? const Color(0xFF3D3BF3) : colors.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingIndigoToolbar extends StatelessWidget {
  final QuillController controller;

  const _FloatingIndigoToolbar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF3D3BF3), // Deep Indigo
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3D3BF3).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            QuillToolbarHistoryButton(
              isUndo: true,
              controller: controller,
            ),
            QuillToolbarHistoryButton(
              isUndo: false,
              controller: controller,
            ),
            QuillToolbarToggleStyleButton(
              options: const QuillToolbarToggleStyleButtonOptions(),
              controller: controller,
              attribute: Attribute.bold,
            ),
            QuillToolbarToggleStyleButton(
              options: const QuillToolbarToggleStyleButtonOptions(),
              controller: controller,
              attribute: Attribute.italic,
            ),
            QuillToolbarToggleStyleButton(
              options: const QuillToolbarToggleStyleButtonOptions(),
              controller: controller,
              attribute: Attribute.underline,
            ),
          ],
        ),
      ),
    );
  }
}
