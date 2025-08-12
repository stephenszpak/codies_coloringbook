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
import '../../settings/settings_screen.dart';
import '../data/coloring_page.dart';
import '../data/pages_repository.dart';
import '../processing/line_art_local_service.dart';
import '../processing/flood_fill.dart';
import 'widgets/big_button.dart';
import 'adjust_outline_panel.dart';

class CreatePageNotifier extends StateNotifier<CreatePageState> {
  CreatePageNotifier() : super(const CreatePageState());

  void setSourceImage(File? file, Uint8List? bytes) {
    state = state.copyWith(
      sourceImageFile: file,
      sourceImageBytes: bytes,
      previewBytes: null,
    );
  }

  void setOutlineStrength(int strength) {
    state = state.copyWith(outlineStrength: strength);
  }

  void setUseAI(bool useAI) {
    state = state.copyWith(useAI: useAI);
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
  final File? sourceImageFile;
  final Uint8List? sourceImageBytes;
  final Uint8List? previewBytes;
  final int outlineStrength;
  final bool useAI;
  final bool isProcessing;
  final String? errorMessage;

  const CreatePageState({
    this.sourceImageFile,
    this.sourceImageBytes,
    this.previewBytes,
    this.outlineStrength = 50,
    this.useAI = false,
    this.isProcessing = false,
    this.errorMessage,
  });

  CreatePageState copyWith({
    File? sourceImageFile,
    Uint8List? sourceImageBytes,
    Uint8List? previewBytes,
    int? outlineStrength,
    bool? useAI,
    bool? isProcessing,
    String? errorMessage,
  }) {
    return CreatePageState(
      sourceImageFile: sourceImageFile ?? this.sourceImageFile,
      sourceImageBytes: sourceImageBytes ?? this.sourceImageBytes,
      previewBytes: previewBytes ?? this.previewBytes,
      outlineStrength: outlineStrength ?? this.outlineStrength,
      useAI: useAI ?? this.useAI,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(createPageProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Coloring Page'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            HapticsService.lightTap();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.sourceImageFile == null) ...[
              Text(
                'Choose Photo Source',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 16),
              BigButton(
                text: 'Camera',
                icon: Icons.camera_alt,
                onPressed: () => _pickImage(ImageSource.camera),
              ),
              const SizedBox(height: 12),
              BigButton(
                text: 'Photo Library',
                icon: Icons.photo_library,
                onPressed: () => _pickImage(ImageSource.gallery),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Processing Mode',
                      style: theme.textTheme.headlineMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      HapticsService.lightTap();
                      ref.read(createPageProvider.notifier).setSourceImage(null, null);
                    },
                    child: const Text('Change Photo'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              if (settings.openAIEnabled) ...[
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Local (Offline)')),
                    ButtonSegment(value: true, label: Text('AI via OpenAI')),
                  ],
                  selected: {state.useAI},
                  onSelectionChanged: (selection) {
                    HapticsService.selectionClick();
                    ref.read(createPageProvider.notifier).setUseAI(selection.first);
                  },
                ),
                const SizedBox(height: 16),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.offline_bolt, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Using Local Processing (AI disabled)',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      AdjustOutlinePanel(
                        outlineStrength: state.outlineStrength,
                        onChanged: (value) {
                          ref.read(createPageProvider.notifier).setOutlineStrength(value);
                          _generatePreview();
                        },
                        preview: _buildPreview(),
                      ),
                      const SizedBox(height: 16),
                      
                      if (state.errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            state.errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      BigButton(
                        text: state.isProcessing ? 'Processing...' : 'Make Coloring Page',
                        icon: state.isProcessing ? Icons.hourglass_empty : Icons.palette,
                        onPressed: state.isProcessing ? () {} : _createColoringPage,
                        isEnabled: !state.isProcessing,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final state = ref.watch(createPageProvider);
    
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Text('Original', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: state.sourceImageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          state.sourceImageFile!,
                          fit: BoxFit.contain,
                        ),
                      )
                    : const Center(child: Icon(Icons.image)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              Text('Line Art', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: state.previewBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          state.previewBytes!,
                          fit: BoxFit.contain,
                        ),
                      )
                    : const Center(
                        child: Text(
                          'Adjust slider\nto preview',
                          textAlign: TextAlign.center,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        final file = File(image.path);
        final bytes = await file.readAsBytes();
        ref.read(createPageProvider.notifier).setSourceImage(file, bytes);
        _generatePreview();
      }
    } catch (e) {
      ref.read(createPageProvider.notifier).setError('Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> _generatePreview() async {
    final state = ref.read(createPageProvider);
    final settings = ref.read(settingsProvider);
    
    if (state.sourceImageBytes == null) return;

    ref.read(createPageProvider.notifier).setError(null);

    try {
      Uint8List previewBytes;
      
      if (state.useAI && settings.openAIEnabled && settings.apiKey.isNotEmpty) {
        final backend = OpenAIBackend();
        final result = await backend.photoToLineArt(
          state.sourceImageBytes!,
          state.outlineStrength,
          settings.apiKey,
        );
        
        if (result.isSuccess) {
          previewBytes = result.dataOrNull!;
        } else {
          ref.read(createPageProvider.notifier).setError('AI unavailable → using Local');
          final localService = LineArtLocalService();
          final localResult = await localService.processImage(
            state.sourceImageBytes!,
            outlineStrength: state.outlineStrength,
          );
          previewBytes = localResult.dataOrNull!;
        }
      } else {
        final localService = LineArtLocalService();
        final result = await localService.processImage(
          state.sourceImageBytes!,
          outlineStrength: state.outlineStrength,
        );
        
        if (result.isSuccess) {
          previewBytes = result.dataOrNull!;
        } else {
          ref.read(createPageProvider.notifier).setError(result.errorMessage);
          return;
        }
      }
      
      ref.read(createPageProvider.notifier).setPreview(previewBytes);
    } catch (e) {
      ref.read(createPageProvider.notifier).setError('Failed to generate preview: ${e.toString()}');
    }
  }

  Future<void> _createColoringPage() async {
    final state = ref.read(createPageProvider);
    final settings = ref.read(settingsProvider);
    final repository = ref.read(pagesRepositoryProvider);
    
    if (state.sourceImageBytes == null) return;

    ref.read(createPageProvider.notifier).setProcessing(true);
    ref.read(createPageProvider.notifier).setError(null);

    try {
      Uint8List outlineBytes;
      
      if (state.useAI && settings.openAIEnabled && settings.apiKey.isNotEmpty) {
        final backend = OpenAIBackend();
        final result = await backend.photoToLineArt(
          state.sourceImageBytes!,
          state.outlineStrength,
          settings.apiKey,
        );
        
        if (result.isSuccess) {
          outlineBytes = result.dataOrNull!;
        } else {
          ref.read(createPageProvider.notifier).setError('AI unavailable → using Local');
          final localService = LineArtLocalService();
          final localResult = await localService.processImage(
            state.sourceImageBytes!,
            outlineStrength: state.outlineStrength,
          );
          outlineBytes = localResult.dataOrNull!;
        }
      } else {
        final localService = LineArtLocalService();
        final result = await localService.processImage(
          state.sourceImageBytes!,
          outlineStrength: state.outlineStrength,
        );
        
        if (result.isFailure) {
          ref.read(createPageProvider.notifier).setError(result.errorMessage);
          ref.read(createPageProvider.notifier).setProcessing(false);
          return;
        }
        
        outlineBytes = result.dataOrNull!;
      }
      
      final uuid = const Uuid();
      final pageId = uuid.v4();
      final appDir = await repository.getAppDirectory();
      
      final sourceImagePath = '$appDir/source_$pageId.jpg';
      await File(sourceImagePath).writeAsBytes(state.sourceImageBytes!);
      
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