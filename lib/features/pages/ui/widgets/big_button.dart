import 'package:flutter/material.dart';
import '../../../../core/haptics.dart';

class BigButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isEnabled;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool isOutlined;

  const BigButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.isEnabled = true,
    this.backgroundColor,
    this.foregroundColor,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return SizedBox(
      width: double.infinity,
      height: 72,
      child: isOutlined
          ? OutlinedButton.icon(
              onPressed: isEnabled
                  ? () {
                      HapticsService.lightTap();
                      onPressed();
                    }
                  : null,
              icon: Icon(icon, size: 28),
              label: Text(
                text,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: foregroundColor,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: foregroundColor ?? theme.colorScheme.primary,
                side: BorderSide(
                  color: foregroundColor ?? theme.colorScheme.primary,
                  width: 2,
                ),
              ),
            )
          : ElevatedButton.icon(
              onPressed: isEnabled
                  ? () {
                      HapticsService.lightTap();
                      onPressed();
                    }
                  : null,
              icon: Icon(icon, size: 28),
              label: Text(
                text,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: foregroundColor ?? Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor ?? theme.colorScheme.primary,
                foregroundColor: foregroundColor ?? Colors.white,
              ),
            ),
    );
  }
}