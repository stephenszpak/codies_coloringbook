import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../ai/openai_backend.dart';
import '../../../core/haptics.dart';
import '../../../core/result.dart';
import '../../settings/settings_screen.dart';
import '../data/coloring_page.dart';
import '../data/pages_repository.dart';
import '../processing/flood_fill.dart';
import 'widgets/big_button.dart';

class PromptToPageNotifier extends StateNotifier<PromptToPageState> {
  PromptToPageNotifier() : super(const PromptToPageState());

  void setPrompt(String prompt) {
    state = state.copyWith(prompt: prompt);
  }

  void setProcessing(bool processing) {
    state = state.copyWith(isProcessing: processing);
  }

  void setError(String? error) {
    state = state.copyWith(errorMessage: error);
  }
}

class PromptToPageState {
  final String prompt;
  final bool isProcessing;
  final String? errorMessage;

  const PromptToPageState({
    this.prompt = '',
    this.isProcessing = false,
    this.errorMessage,
  });

  PromptToPageState copyWith({
    String? prompt,
    bool? isProcessing,
    String? errorMessage,
  }) {
    return PromptToPageState(
      prompt: prompt ?? this.prompt,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final promptToPageProvider = StateNotifierProvider.autoDispose<PromptToPageNotifier, PromptToPageState>((ref) {
  return PromptToPageNotifier();
});

class PromptToPageScreen extends ConsumerStatefulWidget {
  const PromptToPageScreen({super.key});

  @override
  ConsumerState<PromptToPageScreen> createState() => _PromptToPageScreenState();
}

class _PromptToPageScreenState extends ConsumerState<PromptToPageScreen> {
  final TextEditingController _textController = TextEditingController();
  
  final List<String> _quickPrompts = [
    'happy dinosaur',
    'kitten with yarn',
    'race car',
    'space rocket',
    'princess castle',
    'friendly robot',
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(promptToPageProvider);
    final settings = ref.watch(settingsProvider);

    if (!settings.openAIEnabled) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Words to Page'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              HapticsService.lightTap();
              Navigator.of(context).pop();
            },
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.psychology_alt,
                  size: 80,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'AI Required',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Turn on AI in Settings to use this feature.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                BigButton(
                  text: 'Go to Settings',
                  icon: Icons.settings,
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/settings');
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Words to Page'),
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
            Text(
              'Describe what you want to color',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: 'Type your idea here...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (value) {
                ref.read(promptToPageProvider.notifier).setPrompt(value);
              },
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'Quick Ideas',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickPrompts.map((prompt) => ActionChip(
                label: Text(prompt),
                onPressed: () {
                  HapticsService.selectionClick();
                  _textController.text = prompt;
                  ref.read(promptToPageProvider.notifier).setPrompt(prompt);
                },
              )).toList(),
            ),
            
            const Spacer(),
            
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
              text: state.isProcessing ? 'Creating...' : 'Create Coloring Page',
              icon: state.isProcessing ? Icons.hourglass_empty : Icons.auto_fix_high,
              onPressed: state.isProcessing || state.prompt.trim().isEmpty 
                  ? () {} 
                  : _createFromPrompt,
              isEnabled: !state.isProcessing && state.prompt.trim().isNotEmpty,
            ),
            
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your words will be sent to OpenAI to create the coloring page.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _createFromPrompt() async {
    final state = ref.read(promptToPageProvider);
    final settings = ref.read(settingsProvider);
    final repository = ref.read(pagesRepositoryProvider);
    
    if (state.prompt.trim().isEmpty || settings.apiKey.isEmpty) return;

    ref.read(promptToPageProvider.notifier).setProcessing(true);
    ref.read(promptToPageProvider.notifier).setError(null);

    try {
      final backend = OpenAIBackend();
      final result = await backend.promptToLineArt(
        state.prompt.trim(),
        settings.apiKey,
      );

      if (result.isFailure) {
        ref.read(promptToPageProvider.notifier).setError('Failed to generate image: ${result.errorMessage}');
        ref.read(promptToPageProvider.notifier).setProcessing(false);
        return;
      }

      final outlineBytes = result.dataOrNull!;
      final uuid = const Uuid();
      final pageId = uuid.v4();
      final appDir = await repository.getAppDirectory();
      
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
        sourceImagePath: null,
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
        ref.read(promptToPageProvider.notifier).setError('Failed to save page: ${saveResult.errorMessage}');
      }
    } catch (e) {
      ref.read(promptToPageProvider.notifier).setError('Failed to create coloring page: ${e.toString()}');
    } finally {
      ref.read(promptToPageProvider.notifier).setProcessing(false);
    }
  }
}