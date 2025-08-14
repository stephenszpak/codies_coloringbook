import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/haptics.dart';

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      maxImageSize: prefs.getInt('max_image_size') ?? 2048,
      isDarkMode: prefs.getBool('dark_mode') ?? false,
    );
  }

  Future<void> setMaxImageSize(int size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('max_image_size', size);
    state = state.copyWith(maxImageSize: size);
  }

  Future<void> setDarkMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_mode', enabled);
    state = state.copyWith(isDarkMode: enabled);
  }
}

class SettingsState {
  final int maxImageSize;
  final bool isDarkMode;

  const SettingsState({
    this.maxImageSize = 2048,
    this.isDarkMode = false,
  });

  SettingsState copyWith({
    int? maxImageSize,
    bool? isDarkMode,
  }) {
    return SettingsState(
      maxImageSize: maxImageSize ?? this.maxImageSize,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }

  // Legacy properties for backward compatibility with existing code
  bool get openAIEnabled => true; // Always enabled now
  String get apiKey => ''; // Not used anymore
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.image,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Image Quality',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Max Image Size',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 1024, label: Text('1024')),
                        ButtonSegment(value: 1536, label: Text('1536')),
                        ButtonSegment(value: 2048, label: Text('2048')),
                      ],
                      selected: {settings.maxImageSize},
                      onSelectionChanged: (selection) {
                        HapticsService.selectionClick();
                        ref.read(settingsProvider.notifier).setMaxImageSize(selection.first);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.palette,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Appearance',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('Dark Mode'),
                      subtitle: const Text('Switch to dark theme'),
                      value: settings.isDarkMode,
                      onChanged: (value) {
                        HapticsService.selectionClick();
                        ref.read(settingsProvider.notifier).setDarkMode(value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.psychology,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AI Coloring Pages',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Photos and prompts are sent to OpenAI to create simple coloring pages perfect for children. All coloring data stays on your device.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}