import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../data/coloring_page.dart';
import 'canvas_painter.dart';
import '../../../../core/haptics.dart';

/// Configuration for zoom behavior that adapts to device characteristics
class ZoomConfig {
  final double maxScale;
  final double doubleTapStep;
  final bool enableBounce;
  
  const ZoomConfig({
    required this.maxScale,
    this.doubleTapStep = 2.0,
    this.enableBounce = false,
  });
  
  /// Default config that adapts to device screen size
  factory ZoomConfig.adaptive(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenDiagonal = math.sqrt(mediaQuery.size.width * mediaQuery.size.width + 
                           mediaQuery.size.height * mediaQuery.size.height);
    
    // Consider tablets as devices with diagonal > 8 inches (roughly 600 logical pixels)
    final isTablet = screenDiagonal > 600;
    
    return ZoomConfig(
      maxScale: isTablet ? 6.0 : 4.0, // 6x on tablets, 4x on phones
      doubleTapStep: 2.0,
      enableBounce: false,
    );
  }
}

/// A comprehensive zoomable and pannable wrapper for the coloring canvas
/// that maintains strict bounds and accurate hit-testing for flood-fill operations.
class ZoomableColoringCanvas extends StatefulWidget {
  final ui.Image? colorLayer;
  final ui.Image? outlineLayer;
  final List<DrawStroke> strokes;
  final Function(Offset)? onTap;
  final Function(Offset)? onPanStart;
  final Function(Offset)? onPanUpdate;
  final VoidCallback? onPanEnd;
  final ZoomConfig? config;

  const ZoomableColoringCanvas({
    super.key,
    this.colorLayer,
    this.outlineLayer,
    this.strokes = const [],
    this.onTap,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
    this.config,
  });

  @override
  State<ZoomableColoringCanvas> createState() => _ZoomableColoringCanvasState();
}

class _ZoomableColoringCanvasState extends State<ZoomableColoringCanvas>
    with TickerProviderStateMixin {
  
  late ZoomConfig _config;
  late TransformationController _transformController;
  late AnimationController _doubleTapAnimationController;
  late Animation<Matrix4> _doubleTapAnimation;
  
  // Transform state tracking
  double _minScale = 1.0; // Calculated based on initial fit-to-canvas scale
  bool _isDoubleTapZooming = false;
  bool _isTwoFingerGesture = false;
  int _pointerCount = 0;
  
  // Cached painter for hit-testing
  CanvasPainter? _painter;
  
  @override
  void initState() {
    super.initState();
    _config = widget.config ?? ZoomConfig.adaptive(context);
    _transformController = TransformationController();
    _doubleTapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _doubleTapAnimation = Matrix4Tween().animate(
      CurvedAnimation(
        parent: _doubleTapAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _updatePainter();
    
    // Listen to animation updates
    _doubleTapAnimation.addListener(() {
      _transformController.value = _doubleTapAnimation.value;
    });
    
    // Initialize with proper scale after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTransform();
    });
  }
  
  /// Initialize the transform controller with the proper fit-to-screen scale
  void _initializeTransform() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final canvasSize = renderBox.size;
    final minScale = _calculateMinScale(canvasSize);
    _minScale = minScale;
    
    // Set the initial transform to show the full image
    _transformController.value = Matrix4.identity()..scale(minScale);
  }
  
  @override
  void didUpdateWidget(ZoomableColoringCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.colorLayer != widget.colorLayer ||
        oldWidget.outlineLayer != widget.outlineLayer ||
        oldWidget.strokes != widget.strokes) {
      _updatePainter();
      // Reinitialize transform when image changes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeTransform();
      });
    }
    if (oldWidget.config != widget.config) {
      _config = widget.config ?? ZoomConfig.adaptive(context);
    }
  }
  
  @override
  void dispose() {
    _transformController.dispose();
    _doubleTapAnimationController.dispose();
    super.dispose();
  }
  
  void _updatePainter() {
    _painter = CanvasPainter(
      colorLayer: widget.colorLayer,
      outlineLayer: widget.outlineLayer,
      strokes: widget.strokes,
    );
  }
  
  /// Calculate the minimum scale (initial fit-to-canvas scale) for the current image.
  /// This is the scale that makes the image fit perfectly within the canvas bounds,
  /// and serves as the lower bound for zoom operations - users cannot zoom out
  /// beyond this initial fit state.
  double _calculateMinScale(Size canvasSize) {
    if (widget.outlineLayer == null) return 1.0;
    
    final imageWidth = widget.outlineLayer!.width.toDouble();
    final imageHeight = widget.outlineLayer!.height.toDouble();
    final imageAspectRatio = imageWidth / imageHeight;
    final canvasAspectRatio = canvasSize.width / canvasSize.height;
    
    // Add padding to ensure the whole image is visible with margin
    const padding = 20.0; // pixels of padding around the image
    final availableWidth = canvasSize.width - (padding * 2);
    final availableHeight = canvasSize.height - (padding * 2);
    
    // Scale to fit the image within the available canvas space with padding
    double scale;
    if (imageAspectRatio > (availableWidth / availableHeight)) {
      scale = availableWidth / imageWidth;
    } else {
      scale = availableHeight / imageHeight;
    }
    
    // Ensure we don't scale up tiny images too much, cap at 1.0
    return math.min(scale, 1.0);
  }
  
  /// Get the image bounds in canvas coordinates at the current transform
  Rect _getImageBoundsInCanvas(Size canvasSize) {
    if (widget.outlineLayer == null) return Rect.zero;
    
    final imageWidth = widget.outlineLayer!.width.toDouble();
    final imageHeight = widget.outlineLayer!.height.toDouble();
    
    final transform = _transformController.value;
    final scale = transform.getMaxScaleOnAxis();
    
    // Calculate where the image would be positioned at min scale (centered)
    final minScale = _calculateMinScale(canvasSize);
    final scaledWidth = imageWidth * minScale;
    final scaledHeight = imageHeight * minScale;
    final centerX = canvasSize.width / 2;
    final centerY = canvasSize.height / 2;
    
    // Apply the current transform to get actual bounds
    final actualWidth = scaledWidth * (scale / minScale);
    final actualHeight = scaledHeight * (scale / minScale);
    
    final translation = transform.getTranslation();
    final left = centerX - actualWidth / 2 + translation.x;
    final top = centerY - actualHeight / 2 + translation.y;
    
    return Rect.fromLTWH(left, top, actualWidth, actualHeight);
  }
  
  /// Clamp the transformation to ensure the image always covers the canvas
  /// and never goes beyond zoom bounds. This prevents gaps/gutters around the
  /// image and enforces the min/max scale limits with no overshoot.
  Matrix4 _clampTransformation(Matrix4 transform, Size canvasSize) {
    if (widget.outlineLayer == null) return transform;
    
    final scale = transform.getMaxScaleOnAxis();
    final minScale = _calculateMinScale(canvasSize);
    
    // Clamp scale to bounds
    final clampedScale = scale.clamp(minScale, _config.maxScale);
    
    // If scale changed, rebuild transform with clamped scale
    if (clampedScale != scale) {
      final translation = transform.getTranslation();
      final centerX = canvasSize.width / 2;
      final centerY = canvasSize.height / 2;
      
      transform = Matrix4.identity()
        ..translate(centerX, centerY)
        ..scale(clampedScale)
        ..translate(-centerX, -centerY)
        ..translate(translation.x, translation.y);
    }
    
    // Only allow panning when zoomed beyond min scale
    if (clampedScale <= minScale) {
      // Reset to centered position at min scale
      return Matrix4.identity()..scale(minScale);
    }
    
    // Clamp translation to ensure image always covers canvas
    final imageWidth = widget.outlineLayer!.width.toDouble();
    final imageHeight = widget.outlineLayer!.height.toDouble();
    final scaledImageWidth = imageWidth * clampedScale;
    final scaledImageHeight = imageHeight * clampedScale;
    
    final translation = transform.getTranslation();
    final centerX = canvasSize.width / 2;
    final centerY = canvasSize.height / 2;
    
    // Calculate bounds for translation to prevent gaps
    final maxTranslateX = (scaledImageWidth - canvasSize.width) / 2;
    final maxTranslateY = (scaledImageHeight - canvasSize.height) / 2;
    
    final clampedTranslateX = translation.x.clamp(-maxTranslateX, maxTranslateX);
    final clampedTranslateY = translation.y.clamp(-maxTranslateY, maxTranslateY);
    
    return Matrix4.identity()
      ..translate(centerX, centerY)
      ..scale(clampedScale)
      ..translate(-centerX, -centerY)
      ..translate(clampedTranslateX, clampedTranslateY);
  }
  
  /// Convert screen coordinates to image coordinates using the current transform.
  /// This ensures accurate hit-testing for flood-fill operations at any zoom level,
  /// with coordinates clamped to valid image bounds to prevent out-of-bounds access.
  Offset? _screenToImageCoordinates(Offset screenOffset, Size canvasSize) {
    if (widget.outlineLayer == null || _painter == null) return null;
    
    final transform = _transformController.value;
    final inverseTransform = Matrix4.tryInvert(transform);
    if (inverseTransform == null) return null;
    
    // Apply inverse transform to get local canvas coordinates
    final localOffset = MatrixUtils.transformPoint(inverseTransform, screenOffset);
    
    // Use the painter's coordinate conversion
    final imageOffset = _painter!.canvasToImageCoordinates(localOffset, canvasSize);
    
    // Clamp to image bounds to ensure valid coordinates
    if (imageOffset != null) {
      final clampedX = imageOffset.dx.clamp(0.0, widget.outlineLayer!.width.toDouble() - 1);
      final clampedY = imageOffset.dy.clamp(0.0, widget.outlineLayer!.height.toDouble() - 1);
      return Offset(clampedX, clampedY);
    }
    
    return null;
  }
  
  /// Handle double-tap to zoom toward the tap point
  void _handleDoubleTap(TapDownDetails details) {
    if (_isDoubleTapZooming) return;
    
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final localOffset = renderBox.globalToLocal(details.globalPosition);
    final canvasSize = renderBox.size;
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final minScale = _calculateMinScale(canvasSize);
    
    Matrix4 targetTransform;
    
    if (currentScale > minScale * 1.1) {
      // Reset to fit if currently zoomed
      targetTransform = Matrix4.identity()..scale(minScale);
      HapticsService.lightTap();
    } else {
      // Zoom toward tap point
      final targetScale = (minScale * _config.doubleTapStep).clamp(minScale, _config.maxScale);
      
      // Calculate translation to center the tap point
      final centerX = canvasSize.width / 2;
      final centerY = canvasSize.height / 2;
      final offsetX = centerX - localOffset.dx;
      final offsetY = centerY - localOffset.dy;
      
      targetTransform = Matrix4.identity()
        ..translate(centerX, centerY)
        ..scale(targetScale)
        ..translate(-centerX, -centerY)
        ..translate(offsetX, offsetY);
      
      // Clamp the transformation
      targetTransform = _clampTransformation(targetTransform, canvasSize);
      
      // Provide haptic feedback based on whether we hit max zoom
      if (targetScale >= _config.maxScale) {
        HapticsService.mediumTap(); // Stronger feedback when hitting max
      } else {
        HapticsService.lightTap();
      }
    }
    
    _isDoubleTapZooming = true;
    _doubleTapAnimation = Matrix4Tween(
      begin: _transformController.value,
      end: targetTransform,
    ).animate(CurvedAnimation(
      parent: _doubleTapAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _doubleTapAnimationController.forward(from: 0).then((_) {
      _isDoubleTapZooming = false;
    });
  }
  
  /// Reset the view to initial fit-to-canvas state
  void _resetView() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final canvasSize = renderBox.size;
    final minScale = _calculateMinScale(canvasSize);
    final targetTransform = Matrix4.identity()..scale(minScale);
    
    _isDoubleTapZooming = true;
    _doubleTapAnimation = Matrix4Tween(
      begin: _transformController.value,
      end: targetTransform,
    ).animate(CurvedAnimation(
      parent: _doubleTapAnimationController,
      curve: Curves.easeInOut,
    ));
    
    HapticsService.lightTap();
    _doubleTapAnimationController.forward(from: 0).then((_) {
      _isDoubleTapZooming = false;
    });
  }
  
  /// Handle transform changes from InteractiveViewer
  void _onTransformChanged() {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final canvasSize = renderBox.size;
    _minScale = _calculateMinScale(canvasSize);
    
    // Clamp the transformation
    final clampedTransform = _clampTransformation(_transformController.value, canvasSize);
    
    if (_transformController.value != clampedTransform) {
      _transformController.value = clampedTransform;
    }
    
    // Provide haptic feedback when hitting max zoom
    final currentScale = _transformController.value.getMaxScaleOnAxis();
    if (currentScale >= _config.maxScale - 0.01) {
      // Only trigger once per gesture by checking if we just hit the limit
      HapticsService.mediumTap();
    }
  }
  
  /// Handle pointer events to track gesture state
  void _onPointerDown(PointerDownEvent event) {
    _pointerCount++;
    _isTwoFingerGesture = _pointerCount >= 2;
  }
  
  void _onPointerUp(PointerUpEvent event) {
    _pointerCount--;
    if (_pointerCount <= 1) {
      _isTwoFingerGesture = false;
    }
  }
  
  /// Handle tap for flood-fill, but only if it's a single-finger gesture
  void _handleTap(TapUpDetails details) {
    if (_isTwoFingerGesture || _isDoubleTapZooming) return;
    
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || widget.onTap == null) return;
    
    final localOffset = renderBox.globalToLocal(details.globalPosition);
    final imageOffset = _screenToImageCoordinates(localOffset, renderBox.size);
    
    if (imageOffset != null) {
      widget.onTap!(imageOffset);
    }
  }
  
  /// Handle pan start for stroke drawing
  void _handlePanStart(ScaleStartDetails details) {
    if (_isTwoFingerGesture || widget.onPanStart == null) return;
    
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final localOffset = renderBox.globalToLocal(details.focalPoint);
    final imageOffset = _screenToImageCoordinates(localOffset, renderBox.size);
    
    if (imageOffset != null) {
      widget.onPanStart!(imageOffset);
    }
  }
  
  /// Handle pan update for stroke drawing
  void _handlePanUpdate(ScaleUpdateDetails details) {
    if (_isTwoFingerGesture || widget.onPanUpdate == null) return;
    
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final localOffset = renderBox.globalToLocal(details.focalPoint);
    final imageOffset = _screenToImageCoordinates(localOffset, renderBox.size);
    
    if (imageOffset != null) {
      widget.onPanUpdate!(imageOffset);
    }
  }
  
  /// Handle pan end for stroke drawing
  void _handlePanEnd(ScaleEndDetails details) {
    if (!_isTwoFingerGesture && widget.onPanEnd != null) {
      widget.onPanEnd!();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Reset view button
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 36,
              height: 36,
              child: IconButton(
                onPressed: _resetView,
                icon: const Icon(Icons.center_focus_strong, size: 20),
                tooltip: 'Reset View',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.1),
                  shape: const CircleBorder(),
                ),
              ),
            ),
          ),
        ),
        
        // Main canvas area
        Expanded(
          child: Listener(
            onPointerDown: _onPointerDown,
            onPointerUp: _onPointerUp,
            child: GestureDetector(
              onTapUp: _handleTap,
              onDoubleTapDown: _handleDoubleTap,
              child: InteractiveViewer(
                transformationController: _transformController,
                onInteractionStart: (details) {
                  _pointerCount = details.pointerCount;
                  _isTwoFingerGesture = _pointerCount >= 2;
                  if (!_isTwoFingerGesture) {
                    _handlePanStart(details);
                  }
                },
                onInteractionUpdate: (details) {
                  _onTransformChanged();
                  if (!_isTwoFingerGesture) {
                    _handlePanUpdate(details);
                  }
                },
                onInteractionEnd: _handlePanEnd,
                minScale: 0.01, // Very small minimum to allow our clamping to take control
                maxScale: 20.0, // Large maximum to allow our clamping to take control  
                boundaryMargin: const EdgeInsets.all(0),
                constrained: true, // Use constraints to help with sizing
                scaleEnabled: true,
                panEnabled: true,
                clipBehavior: Clip.none, // Don't clip to allow full image visibility
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _painter,
                    size: Size(
                      widget.outlineLayer?.width.toDouble() ?? 1024,
                      widget.outlineLayer?.height.toDouble() ?? 1024,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}