import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class PrincessCastleIntro extends StatelessWidget {
  final bool repeat;
  final EdgeInsetsGeometry padding;

  const PrincessCastleIntro({
    super.key,
    this.repeat = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 24.0),
  });

  @override
  Widget build(BuildContext context) {
    print('🏰 PrincessCastleIntro building...');
    return Container(
      constraints: const BoxConstraints(maxWidth: 700),
      padding: padding,
      child: SizedBox(
        height: 200,
        child: Semantics(
          label: 'Princess walking toward a castle',
          child: _buildAnimation(),
        ),
      ),
    );
  }

  Widget _buildAnimation() {
    try {
      print('🎬 Building Lottie animation...');
      return Lottie.asset(
        'assets/animations/princess_castle.json',
        fit: BoxFit.fitHeight,
        repeat: repeat,
        frameRate: FrameRate.max,
        delegates: LottieDelegates(
          values: [
            // Hide the backdrop layer by making it transparent
            ValueDelegate.colorFilter(
              const ['Backdrop', '**'],
              value: ColorFilter.mode(Colors.transparent, BlendMode.srcIn),
            ),
          ],
        ),
        onLoaded: (composition) {
          print('✅ Lottie loaded successfully: ${composition.duration}');
        },
        errorBuilder: (context, error, stackTrace) {
          print('❌ Lottie error: $error');
          return _buildFallback();
        },
      );
    } catch (e) {
      print('💥 Lottie exception: $e');
      return _buildFallback();
    }
  }

  Widget _buildFallback() {
    print('🔄 Showing fallback UI');
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.animation,
              size: 48,
              color: Colors.grey,
            ),
            SizedBox(height: 8),
            Text(
              'Princess walking toward a castle',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}