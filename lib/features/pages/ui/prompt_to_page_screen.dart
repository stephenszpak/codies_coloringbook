import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../ai/openai_backend.dart';
import '../../../core/haptics.dart';
import '../../../core/result.dart';
import '../../../widgets/crayon_loader.dart';
import '../../../services/speech_service.dart';
import '../../settings/settings_screen.dart';
import '../data/coloring_page.dart';
import '../data/pages_repository.dart';
import '../processing/flood_fill.dart';
import 'widgets/big_button.dart';
import 'create_page_screen.dart';

class PromptToPageNotifier extends StateNotifier<PromptToPageState> {
  PromptToPageNotifier() : super(const PromptToPageState());

  void setPrompt(String prompt) {
    state = state.copyWith(prompt: prompt);
  }

  void setArtStyle(ArtStyle style) {
    state = state.copyWith(artStyle: style);
  }

  void unlockAdvancedMode() {
    state = state.copyWith(isAdvancedModeUnlocked: true);
  }

  void setProcessing(bool processing) {
    state = state.copyWith(
      isProcessing: processing,
      progress: processing ? 0.1 : 0.0, // Start with small progress when processing
    );
  }

  void setProgress(double progress) {
    state = state.copyWith(progress: progress);
  }

  void setError(String? error) {
    state = state.copyWith(
      errorMessage: error,
      progress: 0.0,
    );
  }

  void setSpeechAvailable(bool available) {
    state = state.copyWith(isSpeechAvailable: available);
  }

  void setListening(bool listening) {
    state = state.copyWith(isListening: listening);
  }

  void setSpeechError(String? error) {
    state = state.copyWith(speechError: error);
  }
}

class PromptToPageState {
  final String prompt;
  final ArtStyle artStyle;
  final bool isProcessing;
  final String? errorMessage;
  final double progress;
  final bool isAdvancedModeUnlocked;
  final bool isSpeechAvailable;
  final bool isListening;
  final String? speechError;

  const PromptToPageState({
    this.prompt = '',
    this.artStyle = ArtStyle.cartoon,
    this.isProcessing = false,
    this.errorMessage,
    this.progress = 0.0,
    this.isAdvancedModeUnlocked = false,
    this.isSpeechAvailable = false,
    this.isListening = false,
    this.speechError,
  });

  PromptToPageState copyWith({
    String? prompt,
    ArtStyle? artStyle,
    bool? isProcessing,
    String? errorMessage,
    double? progress,
    bool? isAdvancedModeUnlocked,
    bool? isSpeechAvailable,
    bool? isListening,
    String? speechError,
  }) {
    return PromptToPageState(
      prompt: prompt ?? this.prompt,
      artStyle: artStyle ?? this.artStyle,
      isProcessing: isProcessing ?? this.isProcessing,
      errorMessage: errorMessage ?? this.errorMessage,
      progress: progress ?? this.progress,
      isAdvancedModeUnlocked: isAdvancedModeUnlocked ?? this.isAdvancedModeUnlocked,
      isSpeechAvailable: isSpeechAvailable ?? this.isSpeechAvailable,
      isListening: isListening ?? this.isListening,
      speechError: speechError ?? this.speechError,
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

class _PromptToPageScreenState extends ConsumerState<PromptToPageScreen> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final SpeechService _speechService = SpeechService();
  bool _hasShownPermissionDialog = false;
  
  final List<String> _quickPrompts = [
    'happy dinosaur',
    'kitten with yarn',
    'race car',
    'space rocket',
    'princess castle',
    'friendly robot',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSpeech();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // Cancel any ongoing speech recognition
    if (_speechService.isListening) {
      _speechService.cancelListening();
    }
    
    // Clear speech service callbacks to prevent access after disposal
    _speechService.onResult = null;
    _speechService.onError = null;
    _speechService.onComplete = null;
    
    _textController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // When app resumes (user returns from Settings), refresh speech availability
    if (state == AppLifecycleState.resumed && _hasShownPermissionDialog) {
      _hasShownPermissionDialog = false;
      _refreshSpeechAvailability();
    }
  }

  Future<void> _refreshSpeechAvailability() async {
    final isAvailable = await _speechService.isSpeechAvailable;
    final permissionState = await _speechService.checkMicAndSpeechPermissions();
    
    // Debug logging
    print('Speech available: $isAvailable');
    print('Permission state: $permissionState');
    
    if (mounted) {
      ref.read(promptToPageProvider.notifier).setSpeechAvailable(
        isAvailable && permissionState == SpeechPermissionState.granted
      );
      
      // Clear any previous speech errors if permission is now granted
      if (permissionState == SpeechPermissionState.granted) {
        ref.read(promptToPageProvider.notifier).setSpeechError(null);
      }
    }
  }

  Future<void> _initializeSpeech() async {
    final isAvailable = await _speechService.isSpeechAvailable;
    if (mounted) {
      ref.read(promptToPageProvider.notifier).setSpeechAvailable(isAvailable);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(promptToPageProvider);
    final settings = ref.watch(settingsProvider);

    if (!settings.openAIEnabled) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Create your own coloring page!'),
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
        title: const Text('Create your own coloring page!'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            HapticsService.lightTap();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
              maxLines: 2,
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
            
            const SizedBox(height: 24),
            
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

            if (state.prompt.trim().isNotEmpty) ...[
              _buildStyleToggle(),
              const SizedBox(height: 16),
            ],
            
            BigButton(
              text: state.isProcessing ? 'Creating...' : 'Create Coloring Page',
              icon: state.isProcessing ? Icons.hourglass_empty : Icons.auto_fix_high,
              onPressed: state.isProcessing || state.prompt.trim().isEmpty 
                  ? () {} 
                  : _createFromPrompt,
              isEnabled: !state.isProcessing && state.prompt.trim().isNotEmpty && !state.isListening,
              progress: state.isProcessing ? state.progress : null,
            ),
            
            const SizedBox(height: 16),
            
            // Microphone button for speech input
            if (state.isSpeechAvailable) ...[
              Center(child: _buildMicrophoneButton(state)),
              const SizedBox(height: 16),
            ] else if (state.speechError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.mic_off, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Speech not available on this device',
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStyleToggle() {
    final state = ref.watch(promptToPageProvider);
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
              ref.read(promptToPageProvider.notifier).unlockAdvancedMode();
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
              // Advanced section (note: exactTrace not available for prompts)
              if (state.isAdvancedModeUnlocked) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Advanced (Photo Only)',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildStyleOption(
                        'Exact Trace',
                        '⚡',
                        'Not available for text prompts',
                        ArtStyle.exactTrace,
                        false,
                        isFullWidth: true,
                        isAdvanced: true,
                        isDisabled: true,
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
        ref.read(promptToPageProvider.notifier).setArtStyle(style);
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

  Future<void> _createFromPrompt() async {
    if (!mounted) return;
    
    final state = ref.read(promptToPageProvider);
    final repository = ref.read(pagesRepositoryProvider);
    
    if (state.prompt.trim().isEmpty) return;

    ref.read(promptToPageProvider.notifier).setProcessing(true);
    ref.read(promptToPageProvider.notifier).setError(null);

    try {
      // Progress: Starting AI generation
      ref.read(promptToPageProvider.notifier).setProgress(0.2);
      
      final backend = OpenAIBackend();
      final result = await backend.promptToLineArt(
        state.prompt.trim(),
        artStyle: state.artStyle,
      );

      if (result.isFailure) {
        if (mounted) {
          ref.read(promptToPageProvider.notifier).setError('Failed to generate image: ${result.errorMessage}');
          ref.read(promptToPageProvider.notifier).setProcessing(false);
        }
        return;
      }

      // Progress: Image generated, processing
      if (mounted) {
        ref.read(promptToPageProvider.notifier).setProgress(0.6);
      }

      final outlineBytes = result.dataOrNull!;
      final uuid = const Uuid();
      final pageId = uuid.v4();
      final appDir = await repository.getAppDirectory();
      
      // Progress: Saving files
      if (mounted) {
        ref.read(promptToPageProvider.notifier).setProgress(0.8);
      }
      
      final outlineImagePath = '$appDir/outline_$pageId.png';
      await File(outlineImagePath).writeAsBytes(outlineBytes);
      
      final img = await decodeImageFromList(outlineBytes);
      final workingBytes = FloodFillService.createEmptyColorLayer(img.width, img.height);
      
      final workingImagePath = '$appDir/working_$pageId.png';
      await File(workingImagePath).writeAsBytes(workingBytes);
      
      final thumbnailPath = '$appDir/thumb_$pageId.png';
      await File(thumbnailPath).writeAsBytes(outlineBytes);
      
      // Progress: Finalizing
      if (mounted) {
        ref.read(promptToPageProvider.notifier).setProgress(0.95);
      }
      
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
        // Progress: Complete!
        if (mounted) {
          ref.read(promptToPageProvider.notifier).setProgress(1.0);
        }
        
        // Small delay to show completion
        await Future.delayed(const Duration(milliseconds: 300));
        
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(
            '/coloring',
            arguments: pageId,
          );
        }
      } else {
        if (mounted) {
          ref.read(promptToPageProvider.notifier).setError('Failed to save page: ${saveResult.errorMessage}');
        }
      }
    } catch (e) {
      if (mounted) {
        ref.read(promptToPageProvider.notifier).setError('Failed to create coloring page: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        ref.read(promptToPageProvider.notifier).setProcessing(false);
      }
    }
  }

  Widget _buildMicrophoneButton(PromptToPageState state) {
    return ValueListenableBuilder<SpeechListeningState>(
      valueListenable: _speechService.listeningState,
      builder: (context, listeningState, child) {
        final isListening = listeningState == SpeechListeningState.listening;
        final isProcessing = listeningState == SpeechListeningState.processing;
        final isError = listeningState == SpeechListeningState.error;
        
        String buttonText;
        IconData buttonIcon;
        Color buttonColor;
        
        if (isListening) {
          buttonText = 'Listening...';
          buttonIcon = Icons.mic;
          buttonColor = Colors.red;
        } else if (isProcessing) {
          buttonText = 'Transcribing...';
          buttonIcon = Icons.transcribe;
          buttonColor = Colors.orange;
        } else if (isError) {
          buttonText = 'Try again';
          buttonIcon = Icons.mic_off;
          buttonColor = Colors.grey;
        } else {
          buttonText = 'Start voice input';
          buttonIcon = Icons.mic;
          buttonColor = Colors.green;
        }
        
        return Semantics(
          label: isListening ? 'Listening... (auto-stops after silence)' : 'Start voice input',
          button: true,
          child: SizedBox(
            width: 80,
            height: 80,
            child: ElevatedButton(
              onPressed: state.isProcessing || isProcessing ? null : _toggleSpeechListening,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.withOpacity(0.15),
                foregroundColor: buttonColor,
                shape: const CircleBorder(),
                padding: EdgeInsets.zero,
                elevation: isListening ? 8 : 2,
                side: BorderSide(
                  color: buttonColor,
                  width: 3,
                ),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: isListening
                    ? Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(buttonIcon, size: 36),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.8, end: 1.2),
                            duration: const Duration(milliseconds: 800),
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: buttonColor.withOpacity(0.5),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              );
                            },
                            onEnd: () {
                              // Restart animation
                              if (mounted && isListening) {
                                setState(() {});
                              }
                            },
                          ),
                        ],
                      )
                    : Icon(buttonIcon, size: 36),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggleSpeechListening() async {
    if (_speechService.isListening) {
      // Stop listening
      HapticsService.mediumTap();
      await _speechService.stopListening();
    } else {
      // Check permissions first before starting
      final permissionState = await _speechService.checkMicAndSpeechPermissions();
      
      if (permissionState == SpeechPermissionState.granted) {
        // Start listening directly if we have permission
        HapticsService.lightTap();
        final success = await _speechService.startListening(
          onResult: _onSpeechResult,
          onError: _onSpeechError,
          onComplete: _onSpeechComplete,
          pauseFor: const Duration(milliseconds: 1800), // 1.8 seconds like modern platforms
          listenFor: const Duration(seconds: 30), // Max listening time
        );
        
        if (!success) {
          _onSpeechError('Failed to start listening');
        }
      } else if (permissionState == SpeechPermissionState.permanentlyDenied) {
        // Show settings dialog for permanently denied
        _showPermissionDialog(isPermanentlyDenied: true);
      } else {
        // Try to request permission
        HapticsService.lightTap();
        final requestResult = await _speechService.requestMicAndSpeechPermissions();
        
        if (requestResult == SpeechPermissionState.granted) {
          // Permission granted, start listening
          final success = await _speechService.startListening(
            onResult: _onSpeechResult,
            onError: _onSpeechError,
            onComplete: _onSpeechComplete,
            pauseFor: const Duration(milliseconds: 1800), // 1.8 seconds like modern platforms
            listenFor: const Duration(seconds: 30), // Max listening time
          );
          
          if (!success) {
            _onSpeechError('Failed to start listening');
          }
        } else {
          // Permission denied, show dialog
          _showPermissionDialog(
            isPermanentlyDenied: requestResult == SpeechPermissionState.permanentlyDenied
          );
        }
      }
    }
  }

  void _onSpeechResult(String result) {
    // Update text field with partial results (don't submit yet)
    if (mounted && result.isNotEmpty) {
      setState(() {
        _textController.text = result;
      });
      ref.read(promptToPageProvider.notifier).setPrompt(result);
    }
  }

  void _onSpeechError(String error) {
    if (mounted) {
      ref.read(promptToPageProvider.notifier).setSpeechError(error);
      
      // Show brief error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onSpeechComplete() {
    if (!mounted) return;
    
    final result = _speechService.lastResult.trim();
    
    if (result.isNotEmpty) {
      // The final result is already in the text field from _onSpeechResult
      // Just ensure the state is synced and auto-submit
      ref.read(promptToPageProvider.notifier).setPrompt(result);
      
      // Auto-submit after successful speech recognition
      HapticsService.mediumTap();
      _createFromPrompt();
    } else {
      // Show hint for empty result
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Didn't catch that—try again."),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showPermissionDialog({bool isPermanentlyDenied = false}) {
    _hasShownPermissionDialog = true;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Microphone Permission Required'),
        content: Text(
          isPermanentlyDenied
              ? 'Voice input requires microphone access. Please go to Settings > Privacy & Security > Microphone and enable access for this app.'
              : 'This app needs microphone access to use voice input. Please grant permission when prompted, or enable it in Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          if (isPermanentlyDenied) ...[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ] else ...[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Try again after user acknowledges
                Future.delayed(const Duration(milliseconds: 500), () {
                  _toggleSpeechListening();
                });
              },
              child: const Text('Try Again'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ],
      ),
    );
  }
}
