import 'package:flutter/material.dart';

class AdjustOutlinePanel extends StatelessWidget {
  final int outlineStrength;
  final ValueChanged<int> onChanged;
  final Widget? preview;

  const AdjustOutlinePanel({
    super.key,
    required this.outlineStrength,
    required this.onChanged,
    this.preview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Outline Strength',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Thin',
                  style: theme.textTheme.bodyMedium,
                ),
                Expanded(
                  child: Slider(
                    value: outlineStrength.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 20,
                    label: outlineStrength.toString(),
                    onChanged: (value) {
                      onChanged(value.round());
                    },
                  ),
                ),
                Text(
                  'Thick',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            if (preview != null) ...[
              const SizedBox(height: 16),
              Text(
                'Preview',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                width: double.infinity,
                child: preview!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}