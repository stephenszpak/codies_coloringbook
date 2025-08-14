import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../pages/ui/widgets/big_button.dart';
import '../../core/haptics.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coloring Book'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.settings, size: 28),
              onPressed: () {
                HapticsService.lightTap();
                Navigator.of(context).pushNamed('/settings');
              },
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            
            Icon(
              Icons.palette,
              size: 80,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Welcome to Coloring Book!',
              style: theme.textTheme.displayMedium,
              textAlign: TextAlign.center,
            ),
            Text(
              'Turn photos into coloring pages',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            
            const Spacer(),
            
            BigButton(
              text: 'New Coloring Page',
              icon: Icons.add_photo_alternate,
              onPressed: () {
                Navigator.of(context).pushNamed('/create-page');
              },
            ),
            
            const SizedBox(height: 16),
            
            BigButton(
              text: 'Create your own coloring page!',
              icon: Icons.text_fields,
              onPressed: settings.openAIEnabled
                  ? () {
                      Navigator.of(context).pushNamed('/prompt-to-page');
                    }
                  : () {
                      _showAIRequiredDialog(context);
                    },
              isEnabled: true,
              backgroundColor: settings.openAIEnabled
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.surfaceVariant,
              foregroundColor: settings.openAIEnabled
                  ? Colors.white
                  : theme.colorScheme.onSurfaceVariant,
            ),
            
            const SizedBox(height: 16),
            
            BigButton(
              text: 'My Pages',
              icon: Icons.folder_open,
              onPressed: () {
                Navigator.of(context).pushNamed('/my-pages');
              },
              isOutlined: true,
            ),
            
            const Spacer(),
            
            TextButton.icon(
              onPressed: () {
                HapticsService.lightTap();
                Navigator.of(context).pushNamed('/help');
              },
              icon: const Icon(Icons.help_outline),
              label: const Text('How to use'),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showAIRequiredDialog(BuildContext context) {
    HapticsService.mediumTap();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI Features Required'),
        content: const Text(
          'Turn on AI in Settings to create coloring pages from words.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticsService.lightTap();
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              HapticsService.lightTap();
              Navigator.of(context).pop();
              Navigator.of(context).pushNamed('/settings');
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }
}
