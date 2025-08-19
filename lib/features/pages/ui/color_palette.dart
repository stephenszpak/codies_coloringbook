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
          final buttonCount = AppTheme.colorPalette.length + 2; // +1 for eraser, +1 for skin tone
          final spacing = 8.0;
          final totalSpacing = spacing * (buttonCount - 1);
          final buttonSize = ((availableWidth - totalSpacing) / buttonCount).clamp(40.0, 56.0);
          
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ...AppTheme.colorPalette.map((color) => 
                Flexible(child: _buildColorButton(color, buttonSize))),
              Flexible(child: _buildSkinToneButton(buttonSize)),
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

  Widget _buildSkinToneButton([double size = 56]) {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () {
          HapticsService.selectionClick();
          _showSkinTonePicker(context);
        },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.brown.shade300,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.brown.shade200,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          gradient: LinearGradient(
            colors: [
              const Color(0xFFFDBCB4), // Light skin tone
              const Color(0xFFD08B5B), // Medium skin tone
              const Color(0xFF8D5524), // Dark skin tone
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Icon(
          Icons.person,
          color: Colors.white,
          size: size * 0.43,
        ),
      ),
      ),
    );
  }

  void _showSkinTonePicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Choose Skin Tone',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 280,
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: _skinToneColors.map((color) {
                return GestureDetector(
                  onTap: () {
                    HapticsService.selectionClick();
                    onColorChanged(color);
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.shade400,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  static const List<Color> _skinToneColors = [
    Color(0xFFFDBCB4), // Very light
    Color(0xFFF1C27D), // Light
    Color(0xFFE0AC69), // Light-medium
    Color(0xFFC68642), // Medium-light
    Color(0xFFD08B5B), // Medium
    Color(0xFFBD723C), // Medium-dark
    Color(0xFFAD6834), // Dark-medium
    Color(0xFF8D5524), // Dark
    Color(0xFF6F4E37), // Darker
    Color(0xFF5D4037), // Very dark
    Color(0xFF4A2C2A), // Deep
    Color(0xFF3C2415), // Deepest
  ];
}