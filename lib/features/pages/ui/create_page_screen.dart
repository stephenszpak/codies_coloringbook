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
import '../../../widgets/crayon_loader.dart';
import '../data/coloring_page.dart';
import '../data/pages_repository.dart';
import '../processing/flood_fill.dart';

enum CreatePageMode { photo, prompt }
enum ArtStyle { cartoon, realistic, exactTrace }

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

  void setArtStyle(ArtStyle style) {
    state = state.copyWith(artStyle: style);
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

  void unlockAdvancedMode() {
    state = state.copyWith(isAdvancedModeUnlocked: true);
  }

  void setUseCharacterizer(bool useCharacterizer) {
    state = state.copyWith(useCharacterizer: useCharacterizer);
  }

  void setBackgroundDetail(double backgroundDetail) {
    state = state.copyWith(backgroundDetail: backgroundDetail);
  }
}

class CreatePageState {
  final CreatePageMode mode;
  final File? sourceImageFile;
  final Uint8List? sourceImageBytes;
  final String prompt;
  final Uint8List? previewBytes;
  final int outlineStrength;
  final ArtStyle artStyle;
  final bool isProcessing;
  final String? errorMessage;
  final bool isAdvancedModeUnlocked;
  final bool useCharacterizer;
  final double backgroundDetail;

  const CreatePageState({
    this.mode = CreatePageMode.photo,
    this.sourceImageFile,
    this.sourceImageBytes,
    this.prompt = '',
    this.previewBytes,
    this.outlineStrength = 50,
    this.artStyle = ArtStyle.cartoon,
    this.isProcessing = false,
    this.errorMessage,
    this.isAdvancedModeUnlocked = false,
    this.useCharacterizer = false,
    this.backgroundDetail = 0.2, // Default to Low
  });

  CreatePageState copyWith({
    CreatePageMode? mode,
    File? sourceImageFile,
    Uint8List? sourceImageBytes,
    String? prompt,
    Uint8List? previewBytes,
    int? outlineStrength,
    ArtStyle? artStyle,
    bool? isProcessing,
    String? errorMessage,
    bool? isAdvancedModeUnlocked,
    bool? useCharacterizer,
    double? backgroundDetail,
  }) {
    return CreatePageState(
      mode: mode ?? this.mode,
      sourceImageFile: sourceImageFile ?? this.sourceImageFile,
      sourceImageBytes: sourceImageBytes ?? this.sourceImageBytes,
      prompt: prompt ?? this.prompt,
      previewBytes: previewBytes ?? this.previewBytes,
      outlineStrength: outlineStrength ?? this.outlineStrength,
      artStyle: artStyle ?? this.artStyle,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: errorMessage ?? this.errorMessage,
      isAdvancedModeUnlocked: isAdvancedModeUnlocked ?? this.isAdvancedModeUnlocked,
      useCharacterizer: useCharacterizer ?? this.useCharacterizer,
      backgroundDetail: backgroundDetail ?? this.backgroundDetail,
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
          onPressed: state.isProcessing ? null : () {
            HapticsService.lightTap();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Stack(
        children: [
          Container(
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
                    ],
                    
                    // Prompt Mode
                    if (state.mode == CreatePageMode.prompt) ...[
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
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _promptController,
                          onChanged: (value) => ref.read(createPageProvider.notifier).setPrompt(value),
                          decoration: const InputDecoration(
                            hintText: 'A happy cat, a big tree, a princess...',
                            hintStyle: TextStyle(fontSize: 20),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(24),
                          ),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
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
                    ],
                    
                    // Photo selected - show preview
                    if (state.mode == CreatePageMode.photo && state.sourceImageFile != null) ...[
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
                      const SizedBox(height: 20),
                      _buildCharacterizerControls(),
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
                    
                    // Style Toggle
                    if ((state.mode == CreatePageMode.photo && state.sourceImageFile != null) || 
                        (state.mode == CreatePageMode.prompt && state.prompt.isNotEmpty)) ...[
                      const SizedBox(height: 16),
                      _buildStyleToggle(),
                      const SizedBox(height: 16),
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
          // Loading overlay when processing
          if (state.isProcessing)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CrayonLoader(
                  size: 120,
                  message: 'Creating your coloring page...',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCharacterizerControls() {
    final state = ref.watch(createPageProvider);
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toggle Row
          Row(
            children: [
              Icon(
                Icons.auto_fix_high,
                color: Colors.blue.shade600,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Keep Subject, Simplify Background',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                    fontSize: 16,
                  ),
                ),
              ),
              Switch.adaptive(
                value: state.useCharacterizer,
                onChanged: (value) {
                  HapticsService.lightTap();
                  ref.read(createPageProvider.notifier).setUseCharacterizer(value);
                },
                activeColor: Colors.blue.shade600,
              ),
            ],
          ),
          
          // Background Detail Slider (shown when toggle is on)
          if (state.useCharacterizer) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.landscape,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Background Detail',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Low',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: state.backgroundDetail,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    activeColor: Colors.blue.shade600,
                    inactiveColor: Colors.blue.shade200,
                    onChanged: (value) {
                      ref.read(createPageProvider.notifier).setBackgroundDetail(value);
                    },
                  ),
                ),
                Text(
                  'High',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStyleToggle() {
    final state = ref.watch(createPageProvider);
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.shade100,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GestureDetector(
            onLongPress: () {
              ref.read(createPageProvider.notifier).unlockAdvancedMode();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Art Style',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade800,
                  ),
                ),
                if (!state.isAdvancedModeUnlocked)
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.purple.shade600,
                    size: 20,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Main style options
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildStyleOption(
                      'Cartoon',
                      '🎨',
                      'Fun & simple',
                      ArtStyle.cartoon,
                      state.artStyle == ArtStyle.cartoon,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStyleOption(
                      'Realistic',
                      '📸',
                      'Natural look',
                      ArtStyle.realistic,
                      state.artStyle == ArtStyle.realistic,
                    ),
                  ),
                ],
              ),
              // Advanced section
              if (state.isAdvancedModeUnlocked) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Advanced',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildStyleOption(
                        'Exact Trace',
                        '⚡',
                        'Exact geometry; less stylized',
                        ArtStyle.exactTrace,
                        state.artStyle == ArtStyle.exactTrace,
                        isFullWidth: true,
                        isAdvanced: true,
                        isDisabled: state.mode == CreatePageMode.prompt,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStyleOption(
    String label, 
    String emoji, 
    String description,
    ArtStyle style, 
    bool isSelected, {
    bool isFullWidth = false,
    bool isAdvanced = false,
    bool isDisabled = false,
  }) {
    return GestureDetector(
      onTap: isDisabled ? null : () {
        HapticsService.lightTap();
        ref.read(createPageProvider.notifier).setArtStyle(style);
      },
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDisabled 
              ? Colors.grey.shade200
              : isSelected 
                  ? (isAdvanced ? Colors.orange.shade100 : Colors.purple.shade100)
                  : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDisabled
                ? Colors.grey.shade300
                : isSelected 
                    ? (isAdvanced ? Colors.orange.shade400 : Colors.purple.shade400)
                    : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: TextStyle(
                fontSize: isFullWidth ? 24 : 28,
                color: isDisabled ? Colors.grey.shade400 : null,
              ),
            ),
            SizedBox(width: isFullWidth ? 12 : 4),
            Expanded(
              child: Column(
                crossAxisAlignment: isFullWidth ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: isFullWidth ? 14 : 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isDisabled 
                          ? Colors.grey.shade400
                          : isSelected 
                              ? (isAdvanced ? Colors.orange.shade800 : Colors.purple.shade800)
                              : Colors.grey.shade700,
                    ),
                    textAlign: isFullWidth ? TextAlign.left : TextAlign.center,
                  ),
                  if (isFullWidth && description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDisabled 
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ],
                ],
              ),
            ),
          ],
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
              style: const TextStyle(
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE9D5FF), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0xFFF3E8FF),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
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
            offset: const Offset(0, 4),
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
      if (image != null && mounted) {
        final file = File(image.path);
        final bytes = await file.readAsBytes();
        if (mounted) {
          ref.read(createPageProvider.notifier).setSourceImage(file, bytes);
        }
      }
    } catch (e) {
      if (mounted) {
        ref.read(createPageProvider.notifier).setError('Failed to pick image: ${e.toString()}');
      }
    }
  }

  Future<void> _createColoringPage() async {
    if (!mounted) return;
    
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
          artStyle: state.artStyle,
          useCharacterizer: state.useCharacterizer,
          backgroundDetail: state.backgroundDetail,
        );
        
        if (!mounted) return;
        
        if (result.isFailure) {
          ref.read(createPageProvider.notifier).setError('AI processing failed: ${result.errorMessage}');
          ref.read(createPageProvider.notifier).setProcessing(false);
          return;
        }
        
        outlineBytes = result.dataOrNull!;
      } else if (state.mode == CreatePageMode.prompt && state.prompt.isNotEmpty) {
        final result = await backend.promptToLineArt(
          state.prompt,
          artStyle: state.artStyle,
        );
        
        if (!mounted) return;
        
        if (result.isFailure) {
          ref.read(createPageProvider.notifier).setError('AI processing failed: ${result.errorMessage}');
          ref.read(createPageProvider.notifier).setProcessing(false);
          return;
        }
        
        outlineBytes = result.dataOrNull!;
      } else {
        if (!mounted) return;
        ref.read(createPageProvider.notifier).setError('Please select a photo or enter a prompt');
        ref.read(createPageProvider.notifier).setProcessing(false);
        return;
      }
      
      const uuid = Uuid();
      final pageId = uuid.v4();
      final appDir = await repository.getAppDirectory();
      
      if (!mounted) return;
      
      // Save source image if from photo
      String? sourceImagePath;
      if (state.mode == CreatePageMode.photo && state.sourceImageBytes != null) {
        sourceImagePath = '$appDir/source_$pageId.jpg';
        await File(sourceImagePath).writeAsBytes(state.sourceImageBytes!);
      }
      
      if (!mounted) return;
      
      final outlineImagePath = '$appDir/outline_$pageId.png';
      await File(outlineImagePath).writeAsBytes(outlineBytes);
      
      final img = await decodeImageFromList(outlineBytes);
      final workingBytes = FloodFillService.createEmptyColorLayer(img.width, img.height);
      
      if (!mounted) return;
      
      final workingImagePath = '$appDir/working_$pageId.png';
      await File(workingImagePath).writeAsBytes(workingBytes);
      
      final thumbnailPath = '$appDir/thumb_$pageId.png';
      await File(thumbnailPath).writeAsBytes(outlineBytes);
      
      if (!mounted) return;
      
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
      
      if (!mounted) return;
      
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
      if (mounted) {
        ref.read(createPageProvider.notifier).setError('Failed to create coloring page: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        ref.read(createPageProvider.notifier).setProcessing(false);
      }
    }
  }
}