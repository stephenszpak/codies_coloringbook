import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class CanvasPainter extends CustomPainter {
  final ui.Image? colorLayer;
  final ui.Image? outlineLayer;

  CanvasPainter({
    this.colorLayer,
    this.outlineLayer,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (outlineLayer == null) return;

    final paint = Paint()
      ..filterQuality = FilterQuality.high;

    final srcRect = Rect.fromLTWH(
      0,
      0,
      outlineLayer!.width.toDouble(),
      outlineLayer!.height.toDouble(),
    );

    final dstRect = _calculateDestinationRect(size, srcRect);

    if (colorLayer != null) {
      canvas.drawImageRect(colorLayer!, srcRect, dstRect, paint);
    }

    canvas.drawImageRect(outlineLayer!, srcRect, dstRect, paint);
  }

  Rect _calculateDestinationRect(Size canvasSize, Rect srcRect) {
    final canvasAspectRatio = canvasSize.width / canvasSize.height;
    final imageAspectRatio = srcRect.width / srcRect.height;

    double width, height;
    double left = 0, top = 0;

    if (imageAspectRatio > canvasAspectRatio) {
      width = canvasSize.width;
      height = width / imageAspectRatio;
      top = (canvasSize.height - height) / 2;
    } else {
      height = canvasSize.height;
      width = height * imageAspectRatio;
      left = (canvasSize.width - width) / 2;
    }

    return Rect.fromLTWH(left, top, width, height);
  }

  Offset? canvasToImageCoordinates(Offset canvasOffset, Size canvasSize) {
    if (outlineLayer == null) return null;

    final srcRect = Rect.fromLTWH(
      0,
      0,
      outlineLayer!.width.toDouble(),
      outlineLayer!.height.toDouble(),
    );

    final dstRect = _calculateDestinationRect(canvasSize, srcRect);

    if (!dstRect.contains(canvasOffset)) return null;

    final relativeX = (canvasOffset.dx - dstRect.left) / dstRect.width;
    final relativeY = (canvasOffset.dy - dstRect.top) / dstRect.height;

    final imageX = (relativeX * srcRect.width).round();
    final imageY = (relativeY * srcRect.height).round();

    return Offset(imageX.toDouble(), imageY.toDouble());
  }

  @override
  bool shouldRepaint(CanvasPainter oldDelegate) {
    return colorLayer != oldDelegate.colorLayer ||
           outlineLayer != oldDelegate.outlineLayer;
  }
}

class ColoringCanvas extends StatefulWidget {
  final ui.Image? colorLayer;
  final ui.Image? outlineLayer;
  final Function(Offset)? onTap;

  const ColoringCanvas({
    super.key,
    this.colorLayer,
    this.outlineLayer,
    this.onTap,
  });

  @override
  State<ColoringCanvas> createState() => _ColoringCanvasState();
}

class _ColoringCanvasState extends State<ColoringCanvas> {
  CanvasPainter? _painter;

  @override
  void initState() {
    super.initState();
    _updatePainter();
  }

  @override
  void didUpdateWidget(ColoringCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.colorLayer != widget.colorLayer ||
        oldWidget.outlineLayer != widget.outlineLayer) {
      _updatePainter();
    }
  }

  void _updatePainter() {
    _painter = CanvasPainter(
      colorLayer: widget.colorLayer,
      outlineLayer: widget.outlineLayer,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapUp: (details) {
        if (widget.onTap != null && _painter != null) {
          final renderBox = context.findRenderObject() as RenderBox;
          final localOffset = renderBox.globalToLocal(details.globalPosition);
          final imageOffset = _painter!.canvasToImageCoordinates(
            localOffset,
            renderBox.size,
          );
          if (imageOffset != null) {
            widget.onTap!(imageOffset);
          }
        }
      },
      child: CustomPaint(
        painter: _painter,
        size: Size.infinite,
      ),
    );
  }
}