import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../ai/openai_backend.dart';
import '../../core/haptics.dart';
import '../../core/result.dart';

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(
      openAIEnabled: prefs.getBool('openai_enabled') ?? false,
      apiKey: prefs.getString('openai_api_key') ?? '',
      maxImageSize: prefs.getInt('max_image_size') ?? 2048,
    );
  }

  Future<void> setOpenAIEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('openai_enabled', enabled);
    state = state.copyWith(openAIEnabled: enabled);
  }

  Future<void> setApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('openai_api_key', key);
    state = state.copyWith(apiKey: key);
  }

  Future<void> setMaxImageSize(int size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('max_image_size', size);
    state = state.copyWith(maxImageSize: size);
  }

  Future<void> testConnection() async {
    if (state.apiKey.isEmpty) {
      state = state.copyWith(
        connectionStatus: 'API key required',
        isTestingConnection: false,
      );
      return;
    }

    state = state.copyWith(isTestingConnection: true);
    
    final backend = OpenAIBackend();
    final result = await backend.healthCheck(state.apiKey);
    
    state = state.copyWith(
      isTestingConnection: false,
      connectionStatus: result.fold(
        onSuccess: (_) => 'Connection successful',
        onFailure: (error) => 'Connection failed: $error',
      ),
    );
  }
}

class SettingsState {
  final bool openAIEnabled;
  final String apiKey;
  final int maxImageSize;
  final bool isTestingConnection;
  final String connectionStatus;

  const SettingsState({
    this.openAIEnabled = false,
    this.apiKey = '',
    this.maxImageSize = 2048,
    this.isTestingConnection = false,
    this.connectionStatus = '',
  });

  SettingsState copyWith({
    bool? openAIEnabled,
    String? apiKey,
    int? maxImageSize,
    bool? isTestingConnection,
    String? connectionStatus,
  }) {
    return SettingsState(
      openAIEnabled: openAIEnabled ?? this.openAIEnabled,
      apiKey: apiKey ?? this.apiKey,
      maxImageSize: maxImageSize ?? this.maxImageSize,
      isTestingConnection: isTestingConnection ?? this.isTestingConnection,
      connectionStatus: connectionStatus ?? this.connectionStatus,
    );
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier();
});

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(settingsProvider);
      _apiKeyController.text = settings.apiKey;
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                          Icons.psychology,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AI Features',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Enable OpenAI'),
                      subtitle: const Text('Use AI to create coloring pages'),
                      value: settings.openAIEnabled,
                      onChanged: (value) {
                        HapticsService.selectionClick();
                        ref.read(settingsProvider.notifier).setOpenAIEnabled(value);
                      },
                    ),
                    if (settings.openAIEnabled) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: _apiKeyController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'OpenAI API Key',
                          hintText: 'sk-...',
                          suffixIcon: Icon(Icons.key),
                        ),
                        onChanged: (value) {
                          ref.read(settingsProvider.notifier).setApiKey(value);
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Model: gpt-image-1',
                        style: theme.textTheme.bodyMedium,
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
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: settings.isTestingConnection
                              ? null
                              : () {
                                  HapticsService.lightTap();
                                  ref.read(settingsProvider.notifier).testConnection();
                                },
                          child: settings.isTestingConnection
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Test Connection'),
                        ),
                      ),
                      if (settings.connectionStatus.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: settings.connectionStatus.contains('successful')
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            settings.connectionStatus,
                            style: TextStyle(
                              color: settings.connectionStatus.contains('successful')
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ),
                      ],
                    ],
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
                          Icons.privacy_tip,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Privacy',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'When enabled, selected photos and prompts are sent to OpenAI to make line art. All other data stays on your device.',
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