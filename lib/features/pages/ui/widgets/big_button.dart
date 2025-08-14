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
  final double? progress; // 0.0 to 1.0, null for no progress

  const BigButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.isEnabled = true,
    this.backgroundColor,
    this.foregroundColor,
    this.isOutlined = false,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // If progress is specified, show custom progress button
    if (progress != null) {
      return SizedBox(
        width: double.infinity,
        height: 72,
        child: Stack(
          children: [
            // Progress background
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: (backgroundColor ?? theme.colorScheme.primary).withValues(alpha: 0.1),
                border: Border.all(
                  color: backgroundColor ?? theme.colorScheme.primary,
                  width: 2,
                ),
              ),
            ),
            // Progress fill
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * progress!,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: (backgroundColor ?? theme.colorScheme.primary).withValues(alpha: 0.3),
                ),
              ),
            ),
            // Button content
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isEnabled
                    ? () {
                        HapticsService.lightTap();
                        onPressed();
                      }
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  height: 72,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 28,
                        color: foregroundColor ?? theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        text,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: foregroundColor ?? theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // Original button without progress
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