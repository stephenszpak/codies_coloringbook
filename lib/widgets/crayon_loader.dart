import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class CrayonLoader extends StatelessWidget {
  final double size;
  final String? message;
  final bool showMessage;

  const CrayonLoader({
    super.key,
    this.size = 80,
    this.message,
    this.showMessage = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Lottie.asset(
            'assets/animations/crayon_spinner_loader.json',
            fit: BoxFit.contain,
            repeat: true,
          ),
        ),
        if (showMessage && message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.purple.shade700,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class CrayonLoadingDialog extends StatelessWidget {
  final String message;
  final bool barrierDismissible;

  const CrayonLoadingDialog({
    super.key,
    required this.message,
    this.barrierDismissible = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: CrayonLoader(
        size: 100,
        message: message,
      ),
    );
  }

  /// Show a loading dialog with the crayon spinner
  static void show(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CrayonLoadingDialog(message: message),
    );
  }

  /// Hide the loading dialog
  static void hide(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }
}

class CrayonLoadingScreen extends StatelessWidget {
  final String? message;

  const CrayonLoadingScreen({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CrayonLoader(
          size: 120,
          message: message ?? 'Loading...',
        ),
      ),
    );
  }
}