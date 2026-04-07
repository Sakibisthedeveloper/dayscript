import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/entities/diary_entry.dart';
import '../bloc/diary/diary_bloc.dart';
import '../bloc/auth/auth_bloc.dart';

class EditorScreen extends StatefulWidget {
  final DiaryEntry? entry;

  const EditorScreen({super.key, this.entry});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  String _currentMood = 'Reflective';
  Timer? _autoSaveTimer;
  double _fontSize = 16.0; // Fix 3: font size state

  static const List<_FontSizeOption> _fontSizeOptions = [
    _FontSizeOption(label: 'Small', size: 13.0),
    _FontSizeOption(label: 'Normal', size: 16.0),
    _FontSizeOption(label: 'Large', size: 20.0),
    _FontSizeOption(label: 'X-Large', size: 24.0),
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry?.title ?? '');
    _contentController = TextEditingController(text: widget.entry?.content ?? '');
    if (widget.entry != null) {
      _currentMood = widget.entry!.mood;
    }

    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_hasChanges()) _autoSaveEntry();
    });
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _saveEntry() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! Authenticated) return;

    final entry = DiaryEntry(
      id: widget.entry?.id ?? const Uuid().v4(),
      title: _titleController.text,
      content: _contentController.text,
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
      content: _contentController.text,
      date: widget.entry?.date ?? DateTime.now(),
      mood: _currentMood,
      tags: widget.entry?.tags ?? [],
      location: widget.entry?.location,
    );

    context.read<DiaryBloc>().add(AutoSaveEntry(authState.user.uid, entry));
  }



  // Fix 3: Show font size picker bottom sheet
  void _showFontSizePicker() {
    final colors = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Text(
                    'Text Size',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                ..._fontSizeOptions.map((opt) {
                  final isSelected = _fontSize == opt.size;
                  return ListTile(
                    leading: Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                      color: isSelected ? colors.primary : colors.onSurfaceVariant,
                    ),
                    title: Text(opt.label, style: TextStyle(fontSize: opt.size)),
                    trailing: isSelected ? Icon(Icons.check, color: colors.primary) : null,
                    onTap: () {
                      setState(() => _fontSize = opt.size);
                      Navigator.of(ctx).pop();
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _hasChanges() {
    final originalTitle = widget.entry?.title ?? '';
    final originalContent = widget.entry?.content ?? '';
    final originalMood = widget.entry?.mood ?? 'Reflective';
    return _titleController.text != originalTitle ||
        _contentController.text != originalContent ||
        _currentMood != originalMood;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isNew = widget.entry == null;

    return BlocListener<DiaryBloc, DiaryState>(
      // Fix 2: Only listen to upload/save states, not every diary state
      listenWhen: (previous, current) =>
          current is DiaryEntryOperationSuccess ||
          current is DiaryError,
      listener: (context, state) {
        if (state is DiaryEntryOperationSuccess) {
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 12),
                Text('Entry saved! ✓', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: colors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        } else if (state is DiaryError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: colors.error),
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
              title: const Text('Discard changes?'),
              content: const Text('You have unsaved changes. Are you sure you want to leave?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text('Discard', style: TextStyle(color: colors.error)),
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
            appBar: AppBar(
              backgroundColor: colors.surface.withValues(alpha: 0.9),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.maybePop(context),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isNew ? 'New Entry' : 'Edit Entry',
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
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
                    child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
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
                  Row(
                    children: [
                      Icon(Icons.mood, color: colors.primary, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        'How does this moment feel?',
                        style: textTheme.labelMedium?.copyWith(fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Fix 3: Apply _fontSize to text field
                  TextField(
                    controller: _contentController,
                    maxLines: null,
                    minLines: 15,
                    autofocus: isNew,
                    style: textTheme.bodyLarge?.copyWith(fontSize: _fontSize, height: 1.6),
                    decoration: InputDecoration(
                      hintText: "What's on your mind today?",
                      hintStyle: textTheme.bodyLarge?.copyWith(
                        fontSize: _fontSize,
                        color: colors.outlineVariant.withValues(alpha: 0.6),
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),
            // Fix 4 & 5: Removed Voice and Place buttons
            bottomNavigationBar: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildToolButton(Icons.format_size, 'Size', colors, onTap: _showFontSizePicker),
                    Container(width: 1, height: 32, color: colors.outlineVariant.withValues(alpha: 0.2)),
                    IconButton(
                      style: IconButton.styleFrom(
                        backgroundColor: colors.primaryContainer.withValues(alpha: 0.2),
                        foregroundColor: colors.primary,
                      ),
                      icon: const Icon(Icons.done_all),
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
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colors.onSurfaceVariant),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: colors.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple data class for font size options.
class _FontSizeOption {
  final String label;
  final double size;
  const _FontSizeOption({required this.label, required this.size});
}
