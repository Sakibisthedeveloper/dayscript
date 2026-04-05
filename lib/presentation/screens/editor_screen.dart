import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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

class _EditorScreenState extends State<EditorScreen> {
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  String _currentMood = 'Reflective';
  List<String> _photoUrls = [];
  final ImagePicker _picker = ImagePicker();
  Timer? _autoSaveTimer;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.entry?.title ?? '');
    _contentController = TextEditingController(text: widget.entry?.content ?? '');
    if (widget.entry != null) {
      _currentMood = widget.entry!.mood;
      _photoUrls = List.from(widget.entry!.photoUrls);
    }
    
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_hasChanges()) {
        _autoSaveEntry();
      }
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
      photoUrls: _photoUrls,
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
      photoUrls: _photoUrls,
      tags: widget.entry?.tags ?? [],
      location: widget.entry?.location,
    );

    context.read<DiaryBloc>().add(AutoSaveEntry(authState.user.uid, entry));
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50, // Added compression
      );
      if (image != null && mounted) {
        final authState = context.read<AuthBloc>().state;
        if (authState is Authenticated) {
          context.read<DiaryBloc>().add(UploadImageEvent(authState.user.uid, image));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  bool _hasChanges() {
    final originalTitle = widget.entry?.title ?? '';
    final originalContent = widget.entry?.content ?? '';
    final originalMood = widget.entry?.mood ?? 'Reflective';
    final originalPhotos = widget.entry?.photoUrls ?? [];

    return _titleController.text != originalTitle ||
           _contentController.text != originalContent ||
           _currentMood != originalMood ||
           _photoUrls.length != originalPhotos.length;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isNew = widget.entry == null;

    return BlocListener<DiaryBloc, DiaryState>(
      listener: (context, state) {
        if (state is DiaryEntryOperationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            behavior: SnackBarBehavior.floating,
            backgroundColor: colors.primary,
          ));
          context.pop();
        } else if (state is DiaryImageUploaded) {
          setState(() {
            _photoUrls.add(state.imageUrl);
            _isUploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image uploaded!')));
        } else if (state is DiaryImageUploading) {
          setState(() => _isUploading = true);
        } else if (state is DiaryError) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message), backgroundColor: colors.error));
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
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
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
          onTap: () => FocusScope.of(context).unfocus(), // Keyboard dismiss
          child: Scaffold(
            extendBody: true,
            appBar: AppBar(
              backgroundColor: colors.surface.withOpacity(0.9),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.maybePop(context),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isNew ? 'New Entry' : 'Edit Entry', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  Text(
                    DateFormat('MMMM d, yyyy').format(widget.entry?.date ?? DateTime.now()),
                    style: textTheme.labelSmall,
                  )
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
                )
              ],
              bottom: _isUploading ? PreferredSize(
                preferredSize: const Size.fromHeight(4.0),
                child: LinearProgressIndicator(
                  backgroundColor: colors.surfaceContainerHighest,
                  color: colors.primary,
                ),
              ) : null,
            ),
            body: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24.0, 
                right: 24.0, 
                top: 24.0, 
                bottom: MediaQuery.of(context).viewInsets.bottom + 120.0
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _titleController,
                    style: textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w800, color: colors.onSurface),
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
                      Text('How does this moment feel?', style: textTheme.labelMedium?.copyWith(fontStyle: FontStyle.italic)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_photoUrls.isNotEmpty)
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _photoUrls.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 12.0),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(_photoUrls[index], height: 120, width: 120, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _photoUrls.removeAt(index)),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  if (_photoUrls.isNotEmpty) const SizedBox(height: 24),
                  TextField(
                    controller: _contentController,
                    maxLines: null,
                    minLines: 15,
                    autofocus: isNew, // Auto focus for new entry
                    style: textTheme.bodyLarge?.copyWith(fontSize: 20, height: 1.6),
                    decoration: InputDecoration(
                      hintText: "What's on your mind today?",
                      hintStyle: textTheme.bodyLarge?.copyWith(fontSize: 20, color: colors.outlineVariant.withOpacity(0.6)),
                      border: InputBorder.none,
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: SafeArea(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surface.withOpacity(0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withOpacity(0.12),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildToolButton(Icons.add_a_photo, 'Photo', colors, onTap: _pickImage),
                _buildToolButton(Icons.format_size, 'Size', colors),
                _buildToolButton(Icons.mic, 'Voice', colors),
                _buildToolButton(Icons.location_on, 'Place', colors),
                Container(width: 1, height: 32, color: colors.outlineVariant.withOpacity(0.2)),
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: colors.primaryContainer.withOpacity(0.2),
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
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colors.onSurfaceVariant.withOpacity(0.6))),
          ],
        ),
      ),
    );
  }
}
