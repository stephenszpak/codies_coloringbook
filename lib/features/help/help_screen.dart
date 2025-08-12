import 'package:flutter/material.dart';
import '../../core/haptics.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('How to Use'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            HapticsService.lightTap();
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _HelpStep(
              stepNumber: 1,
              title: 'Pick a Photo',
              description: 'Take a photo or choose one from your photo library',
              icon: Icons.add_photo_alternate,
              iconColor: theme.colorScheme.primary,
            ),
            
            const SizedBox(height: 24),
            
            _HelpStep(
              stepNumber: 2,
              title: 'Make Line Art',
              description: 'Adjust the outline strength and create your coloring page',
              icon: Icons.auto_fix_high,
              iconColor: theme.colorScheme.secondary,
            ),
            
            const SizedBox(height: 24),
            
            _HelpStep(
              stepNumber: 3,
              title: 'Start Coloring!',
              description: 'Tap areas to fill with color. Use undo/redo and save when done',
              icon: Icons.palette,
              iconColor: Colors.green,
            ),
            
            const SizedBox(height: 40),
            
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.tips_and_updates,
                          color: theme.colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tips',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    _Tip(
                      icon: Icons.touch_app,
                      text: 'Tap any white area to fill it with color',
                    ),
                    
                    const SizedBox(height: 12),
                    
                    _Tip(
                      icon: Icons.auto_fix_high,
                      text: 'Use the eraser tool to remove colors',
                    ),
                    
                    const SizedBox(height: 12),
                    
                    _Tip(
                      icon: Icons.undo,
                      text: 'Undo and redo up to 5 actions',
                    ),
                    
                    const SizedBox(height: 12),
                    
                    _Tip(
                      icon: Icons.share,
                      text: 'Export as PNG or PDF to share your art',
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            Card(
              color: theme.colorScheme.primaryContainer.withOpacity(0.5),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
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
                    const SizedBox(height: 12),
                    Text(
                      'Turn on AI in Settings to:',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Create better line art from photos\n'
                      '• Generate coloring pages from text prompts\n'
                      '• Get higher quality results',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Note: AI features require an internet connection and OpenAI API key.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _HelpStep extends StatelessWidget {
  final int stepNumber;
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;

  const _HelpStep({
    required this.stepNumber,
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              stepNumber.toString(),
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 16),
        
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Tip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.onSurface.withOpacity(0.7),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}