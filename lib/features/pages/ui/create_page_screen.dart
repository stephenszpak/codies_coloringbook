import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import '../../../ai/openai_backend.dart';
import '../../../core/haptics.dart';
import '../../../core/result.dart';
import '../data/coloring_page.dart';
import '../data/pages_repository.dart';
import '../processing/flood_fill.dart';

enum CreatePageMode { photo, prompt }

class CreatePageNotifier extends StateNotifier<CreatePageState> {
  CreatePageNotifier() : super(const CreatePageState());

  void setMode(CreatePageMode mode) {
    state = state.copyWith(
      mode: mode,
      sourceImageFile: null,
      sourceImageBytes: null,
      prompt: '',
      previewBytes: null,
    );
  }

  void setSourceImage(File? file, Uint8List? bytes) {
    state = state.copyWith(
      sourceImageFile: file,
      sourceImageBytes: bytes,
      previewBytes: null,
    );
  }

  void setPrompt(String prompt) {
    state = state.copyWith(
      prompt: prompt,
      previewBytes: null,
    );
  }

  void setOutlineStrength(int strength) {
    state = state.copyWith(outlineStrength: strength);
  }

  void setProcessing(bool processing) {
    state = state.copyWith(isProcessing: processing);
  }

  void setPreview(Uint8List? bytes) {
    state = state.copyWith(previewBytes: bytes);
  }

  void setError(String? error) {
    state = state.copyWith(errorMessage: error);
  }
}

class CreatePageState {
  final CreatePageMode mode;
  final File? sourceImageFile;
  final Uint8List? sourceImageBytes;
  final String prompt;
  final Uint8List? previewBytes;
  final int outlineStrength;
  final bool isProcessing;
  final String? errorMessage;

  const CreatePageState({
    this.mode = CreatePageMode.photo,
    this.sourceImageFile,
    this.sourceImageBytes,
    this.prompt = '',
    this.previewBytes,
    this.outlineStrength = 50,
    this.isProcessing = false,
    this.errorMessage,
  });

  CreatePageState copyWith({
    CreatePageMode? mode,
    File? sourceImageFile,
    Uint8List? sourceImageBytes,
    String? prompt,
    Uint8List? previewBytes,
    int? outlineStrength,
    bool? isProcessing,
    String? errorMessage,
  }) {
    return CreatePageState(
      mode: mode ?? this.mode,
      sourceImageFile: sourceImageFile ?? this.sourceImageFile,
      sourceImageBytes: sourceImageBytes ?? this.sourceImageBytes,
      prompt: prompt ?? this.prompt,
      previewBytes: previewBytes ?? this.previewBytes,
      outlineStrength: outlineStrength ?? this.outlineStrength,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final createPageProvider = StateNotifierProvider.autoDispose<CreatePageNotifier, CreatePageState>((ref) {
  return CreatePageNotifier();
});

class CreatePageScreen extends ConsumerStatefulWidget {
  const CreatePageScreen({super.key});

  @override
  ConsumerState<CreatePageScreen> createState() => _CreatePageScreenState();
}

class _CreatePageScreenState extends ConsumerState<CreatePageScreen> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _promptController = TextEditingController();

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(createPageProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'New Coloring Page',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.purple.shade800,
          ),
        ),
        backgroundColor: Colors.purple.shade100,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 32),
          onPressed: () {
            HapticsService.lightTap();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.purple.shade50,
              Colors.pink.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Initial Mode Selection
                if (state.mode == CreatePageMode.photo && state.sourceImageFile == null) ...[
                  Text(
                    'How do you want to make your coloring page?',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.purple.shade800,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _buildGiantButton(
                    'Take a Photo',
                    Icons.camera_alt,
                    Colors.blue,
                    () => _pickImage(ImageSource.camera),
                  ),
                  const SizedBox(height: 20),
                  _buildGiantButton(
                    'Choose Photo',
                    Icons.photo_library,
                    Colors.green,
                    () => _pickImage(ImageSource.gallery),
                  ),
                  const SizedBox(height: 20),
                  _buildGiantButton(
                    'Draw Something!',
                    Icons.create,
                    Colors.orange,
                    () => ref.read(createPageProvider.notifier).setMode(CreatePageMode.prompt),
                  ),
                ]
                
                // Prompt Mode
                else if (state.mode == CreatePageMode.prompt) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'What do you want to color?',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: Colors.purple.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.arrow_back, size: 32, color: Colors.purple.shade600),
                        onPressed: () {
                          HapticsService.lightTap();
                          ref.read(createPageProvider.notifier).setMode(CreatePageMode.photo);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.purple.shade200, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.shade100,
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _promptController,
                      onChanged: (value) => ref.read(createPageProvider.notifier).setPrompt(value),
                      decoration: InputDecoration(
                        hintText: 'A happy cat, a big tree, a princess...',
                        hintStyle: TextStyle(fontSize: 20, color: Colors.grey.shade500),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(24),
                      ),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Quick prompt buttons
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildPromptChip('Cat', '🐱'),
                      _buildPromptChip('Dog', '🐶'),
                      _buildPromptChip('Car', '🚗'),
                      _buildPromptChip('House', '🏠'),
                      _buildPromptChip('Flower', '🌸'),
                      _buildPromptChip('Tree', '🌳'),
                      _buildPromptChip('Princess', '👸'),
                      _buildPromptChip('Robot', '🤖'),
                    ],
                  ),
                  const Spacer(),
                ]
                
                // Photo selected - show preview
                else if (state.sourceImageFile != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Your Photo',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            color: Colors.purple.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.refresh, size: 32, color: Colors.purple.shade600),
                        onPressed: () {
                          HapticsService.lightTap();
                          ref.read(createPageProvider.notifier).setSourceImage(null, null);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSimplePreview(),
                  const Spacer(),
                ],
                
                // Error Display
                if (state.errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.shade300, width: 2),
                    ),
                    child: Text(
                      state.errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade800,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                
                // Create Button
                if ((state.mode == CreatePageMode.photo && state.sourceImageFile != null) || 
                    (state.mode == CreatePageMode.prompt && state.prompt.isNotEmpty)) ...[
                  _buildGiantButton(
                    state.isProcessing ? 'Creating Magic...' : 'Make Coloring Page!',
                    state.isProcessing ? Icons.auto_fix_high : Icons.palette,
                    Colors.purple,
                    state.isProcessing ? null : _createColoringPage,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGiantButton(String text, IconData icon, Color color, VoidCallback? onPressed) {
    return SizedBox(
      height: 100,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color.fromRGBO(color.red, color.green, color.blue, 0.2),
          foregroundColor: Color.fromRGBO((color.red * 0.8).round(), (color.green * 0.8).round(), (color.blue * 0.8).round(), 1.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          shadowColor: Color.fromRGBO(color.red, color.green, color.blue, 0.3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40),
            const SizedBox(width: 16),
            Text(
              text,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptChip(String text, String emoji) {
    return GestureDetector(
      onTap: () {
        HapticsService.lightTap();
        _promptController.text = text.toLowerCase();
        ref.read(createPageProvider.notifier).setPrompt(text.toLowerCase());
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE9D5FF), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF3E8FF),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: TextStyle(fontSize: 24)),
            SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.purple.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimplePreview() {
    final state = ref.watch(createPageProvider);
    
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade100,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: state.sourceImageFile != null
            ? Image.file(
                state.sourceImageFile!,
                fit: BoxFit.contain,
              )
            : Center(
                child: Icon(
                  Icons.image,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
              ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      HapticsService.lightTap();
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        final file = File(image.path);
        final bytes = await file.readAsBytes();
        ref.read(createPageProvider.notifier).setSourceImage(file, bytes);
      }
    } catch (e) {
      ref.read(createPageProvider.notifier).setError('Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> _createColoringPage() async {
    final state = ref.read(createPageProvider);
    final repository = ref.read(pagesRepositoryProvider);
    
    ref.read(createPageProvider.notifier).setProcessing(true);
    ref.read(createPageProvider.notifier).setError(null);

    try {
      HapticsService.lightTap();
      Uint8List outlineBytes;
      final backend = OpenAIBackend();

      if (state.mode == CreatePageMode.photo && state.sourceImageBytes != null) {
        final result = await backend.photoToLineArt(
          state.sourceImageBytes!,
          state.outlineStrength,
        );
        
        if (result.isFailure) {
          ref.read(createPageProvider.notifier).setError('AI processing failed: ${result.errorMessage}');
          ref.read(createPageProvider.notifier).setProcessing(false);
          return;
        }
        
        outlineBytes = result.dataOrNull!;
      } else if (state.mode == CreatePageMode.prompt && state.prompt.isNotEmpty) {
        final result = await backend.promptToLineArt(state.prompt);
        
        if (result.isFailure) {
          ref.read(createPageProvider.notifier).setError('AI processing failed: ${result.errorMessage}');
          ref.read(createPageProvider.notifier).setProcessing(false);
          return;
        }
        
        outlineBytes = result.dataOrNull!;
      } else {
        ref.read(createPageProvider.notifier).setError('Please select a photo or enter a prompt');
        ref.read(createPageProvider.notifier).setProcessing(false);
        return;
      }
      
      final uuid = const Uuid();
      final pageId = uuid.v4();
      final appDir = await repository.getAppDirectory();
      
      // Save source image if from photo
      String? sourceImagePath;
      if (state.mode == CreatePageMode.photo && state.sourceImageBytes != null) {
        sourceImagePath = '$appDir/source_$pageId.jpg';
        await File(sourceImagePath).writeAsBytes(state.sourceImageBytes!);
      }
      
      final outlineImagePath = '$appDir/outline_$pageId.png';
      await File(outlineImagePath).writeAsBytes(outlineBytes);
      
      final img = await decodeImageFromList(outlineBytes);
      final workingBytes = FloodFillService.createEmptyColorLayer(img.width, img.height);
      
      final workingImagePath = '$appDir/working_$pageId.png';
      await File(workingImagePath).writeAsBytes(workingBytes);
      
      final thumbnailPath = '$appDir/thumb_$pageId.png';
      await File(thumbnailPath).writeAsBytes(outlineBytes);
      
      final coloringPage = ColoringPage(
        id: pageId,
        createdAt: DateTime.now(),
        sourceImagePath: sourceImagePath,
        outlineImagePath: outlineImagePath,
        workingImagePath: workingImagePath,
        width: img.width,
        height: img.height,
        thumbnailPath: thumbnailPath,
      );
      
      final saveResult = await repository.savePage(coloringPage);
      if (saveResult.isSuccess) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(
            '/coloring',
            arguments: pageId,
          );
        }
      } else {
        ref.read(createPageProvider.notifier).setError('Failed to save page: ${saveResult.errorMessage}');
      }
    } catch (e) {
      ref.read(createPageProvider.notifier).setError('Failed to create coloring page: ${e.toString()}');
    } finally {
      ref.read(createPageProvider.notifier).setProcessing(false);
    }
  }
}