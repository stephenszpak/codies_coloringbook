import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../../../core/haptics.dart';

class ColorPalette extends StatelessWidget {
  final Color selectedColor;
  final ValueChanged<Color> onColorChanged;
  final VoidCallback onEraserTapped;
  final bool isEraserSelected;

  const ColorPalette({
    super.key,
    required this.selectedColor,
    required this.onColorChanged,
    required this.onEraserTapped,
    required this.isEraserSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate button size based on available width
          final availableWidth = constraints.maxWidth - 32; // Account for padding
          final buttonCount = AppTheme.colorPalette.length + 1; // +1 for eraser
          final spacing = 8.0;
          final totalSpacing = spacing * (buttonCount - 1);
          final buttonSize = ((availableWidth - totalSpacing) / buttonCount).clamp(40.0, 56.0);
          
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ...AppTheme.colorPalette.map((color) => 
                Flexible(child: _buildColorButton(color, buttonSize))),
              Flexible(child: _buildEraserButton(buttonSize)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildColorButton(Color color, [double size = 56]) {
    final isSelected = selectedColor == color && !isEraserSelected;
    
    return GestureDetector(
      onTap: () {
        HapticsService.selectionClick();
        onColorChanged(color);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.grey.shade300,
            width: isSelected ? 4 : 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                color: Colors.white,
                size: size * 0.43, // Proportional to button size
              )
            : null,
      ),
    );
  }

  Widget _buildEraserButton([double size = 56]) {
    return GestureDetector(
      onTap: () {
        HapticsService.selectionClick();
        onEraserTapped();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.pink.shade100,
          shape: BoxShape.circle,
          border: Border.all(
            color: isEraserSelected ? Colors.pink : Colors.grey.shade300,
            width: isEraserSelected ? 4 : 2,
          ),
          boxShadow: isEraserSelected
              ? [
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Icon(
          Icons.auto_fix_high,
          color: isEraserSelected ? Colors.pink : Colors.pink.shade300,
          size: size * 0.43, // Proportional to button size
        ),
      ),
    );
  }
}