import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../data/coloring_page.dart';

class CanvasPainter extends CustomPainter {
  final ui.Image? colorLayer;
  final ui.Image? outlineLayer;
  final List<DrawStroke> strokes;

  CanvasPainter({
    this.colorLayer,
    this.outlineLayer,
    this.strokes = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (outlineLayer == null) return;

    // Use pixel-stable painting with no smoothing to preserve crisp line art
    final colorPaint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;

    final linePaint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false
      ..blendMode = BlendMode.multiply; // Ensures black lines stay on top, white becomes transparent

    final srcRect = Rect.fromLTWH(
      0,
      0,
      outlineLayer!.width.toDouble(),
      outlineLayer!.height.toDouble(),
    );

    final dstRect = _calculateDestinationRect(size, srcRect);

    // PASS 1: Draw color layer (mutable, underneath)
    if (colorLayer != null) {
      canvas.drawImageRect(colorLayer!, srcRect, dstRect, colorPaint);
    }

    // PASS 2: Draw freehand strokes (above colors, below line art)
    for (final stroke in strokes) {
      final scaledStrokeWidth = (stroke.strokeWidth * (dstRect.width / srcRect.width)).clamp(2.0, 50.0);
      final strokePaint = Paint()
        ..color = stroke.color
        ..strokeWidth = scaledStrokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = true; // Allow antialiasing for smooth freehand strokes
      
      // Convert stroke points from image coordinates to canvas coordinates
      final canvasPoints = stroke.points.map((point) {
        final relativeX = point.dx / srcRect.width;
        final relativeY = point.dy / srcRect.height;
        final canvasPoint = Offset(
          dstRect.left + (relativeX * dstRect.width),
          dstRect.top + (relativeY * dstRect.height),
        );
        return canvasPoint;
      }).toList();
      
      if (canvasPoints.length < 2) {
        canvas.drawPoints(ui.PointMode.points, canvasPoints, strokePaint);
      } else {
        for (var i = 1; i < canvasPoints.length; i++) {
          canvas.drawLine(canvasPoints[i - 1], canvasPoints[i], strokePaint);
        }
      }
    }

    // PASS 3: Draw line art layer (immutable, always on top)
    // Use multiply blend mode so black stays solid and white becomes transparent
    canvas.drawImageRect(outlineLayer!, srcRect, dstRect, linePaint);
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
           outlineLayer != oldDelegate.outlineLayer ||
           strokes != oldDelegate.strokes;
  }
}

class ColoringCanvas extends StatefulWidget {
  final ui.Image? colorLayer;
  final ui.Image? outlineLayer;
  final Function(Offset)? onTap;
  final List<DrawStroke> strokes;
  final Function(Offset)? onPanStart;
  final Function(Offset)? onPanUpdate;
  final VoidCallback? onPanEnd;

  const ColoringCanvas({
    super.key,
    this.colorLayer,
    this.outlineLayer,
    this.onTap,
    this.strokes = const [],
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
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
        oldWidget.outlineLayer != widget.outlineLayer ||
        oldWidget.strokes != widget.strokes) {
      _updatePainter();
    }
  }

  void _updatePainter() {
    _painter = CanvasPainter(
      colorLayer: widget.colorLayer,
      outlineLayer: widget.outlineLayer,
      strokes: widget.strokes,
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
      onPanStart: (details) {
        if (widget.onPanStart != null && _painter != null) {
          final renderBox = context.findRenderObject() as RenderBox;
          final localOffset = renderBox.globalToLocal(details.globalPosition);
          final imageOffset = _painter!.canvasToImageCoordinates(
            localOffset,
            renderBox.size,
          );
          if (imageOffset != null) {
            widget.onPanStart!(imageOffset);
          }
        }
      },
      onPanUpdate: (details) {
        if (widget.onPanUpdate != null && _painter != null) {
          final renderBox = context.findRenderObject() as RenderBox;
          final localOffset = renderBox.globalToLocal(details.globalPosition);
          final imageOffset = _painter!.canvasToImageCoordinates(
            localOffset,
            renderBox.size,
          );
          if (imageOffset != null) {
            widget.onPanUpdate!(imageOffset);
          }
        }
      },
      onPanEnd: (_) {
        widget.onPanEnd?.call();
      },
      child: CustomPaint(
        painter: _painter,
        size: const Size(1024, 1024), // Fixed size for better zoom behavior
      ),
    );
  }
}
