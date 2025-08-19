import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;
import '../core/result.dart';
import 'storage_service.dart';
import '../features/pages/ui/widgets/canvas_painter.dart';
import '../features/pages/data/coloring_page.dart';

class ExportService {
  /// Exports the coloring page to PNG using the same two-layer rendering as canvas.
  static Future<Result<String>> exportToPNG(
    ui.Image colorLayer,
    ui.Image outlineLayer, {
    List<DrawStroke> strokes = const <DrawStroke>[],
  }) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Use same paint settings as canvas for pixel-perfect export
      final colorPaint = Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false;

      final linePaint = Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false
        ..blendMode = BlendMode.multiply; // Same blend mode as canvas
      
      final rect = Rect.fromLTWH(0, 0, 
          outlineLayer.width.toDouble(), 
          outlineLayer.height.toDouble());
      
      // PASS 1: Draw color layer (mutable, underneath)
      canvas.drawImageRect(colorLayer, rect, rect, colorPaint);
      
      // PASS 2: Draw freehand strokes (above colors, below line art)
      for (final stroke in strokes) {
        final strokePaint = Paint()
          ..color = stroke.color
          ..strokeWidth = stroke.strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..filterQuality = FilterQuality.none
          ..isAntiAlias = true; // Same as canvas - smooth strokes
        
        if (stroke.points.length < 2) {
          canvas.drawPoints(ui.PointMode.points, stroke.points, strokePaint);
        } else {
          for (var i = 1; i < stroke.points.length; i++) {
            canvas.drawLine(stroke.points[i - 1], stroke.points[i], strokePaint);
          }
        }
      }
      
      // PASS 3: Draw line art layer (immutable, always on top)
      canvas.drawImageRect(outlineLayer, rect, rect, linePaint);
      
      final picture = recorder.endRecording();
      final image = await picture.toImage(
          outlineLayer.width, 
          outlineLayer.height);
      
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'coloring_page_$timestamp.png';
      
      final filePath = await StorageService.saveFile(
        filename, 
        pngBytes,
        subfolder: 'exports',
      );
      
      return Success(filePath);
    } catch (e) {
      return Failure('Failed to export PNG: ${e.toString()}');
    }
  }


  static Future<Result<void>> shareFile(String filePath, {String? text}) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return const Failure('File not found');
      }
      
      await Share.shareXFiles(
        [XFile(filePath)],
        text: text ?? 'Check out my coloring page!',
      );
      
      return const Success(null);
    } catch (e) {
      return Failure('Failed to share file: ${e.toString()}');
    }
  }

  static Future<Result<void>> saveToGallery(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return const Failure('File not found');
      }
      
      await Share.shareXFiles([XFile(filePath)]);
      
      return const Success(null);
    } catch (e) {
      return Failure('Failed to save to gallery: ${e.toString()}');
    }
  }

  /// Saves the coloring page directly to the photo library
  static Future<Result<void>> saveToPhotoLibrary(
    ui.Image colorLayer,
    ui.Image outlineLayer, {
    List<DrawStroke> strokes = const <DrawStroke>[],
  }) async {
    try {
      // Validate input images first
      if (colorLayer.width <= 0 || colorLayer.height <= 0) {
        return const Failure('Invalid color layer image dimensions');
      }
      if (outlineLayer.width <= 0 || outlineLayer.height <= 0) {
        return const Failure('Invalid outline layer image dimensions');
      }
      
      // Always check and request permission fresh each time to avoid stale state
      bool hasPermission = false;
      
      // Get current permission status
      var permissionStatus = await Permission.photos.status;
      
      // If permanently denied, return error immediately
      if (permissionStatus.isPermanentlyDenied) {
        return const Failure('Photo library access was permanently denied. Please enable it in Settings > Privacy & Security > Photos > Coloring Book');
      }
      
      // If restricted, return error
      if (permissionStatus.isRestricted) {
        return const Failure('Photo library access is restricted on this device.');
      }
      
      // If not granted, request permission
      if (!permissionStatus.isGranted) {
        final newPermission = await Permission.photos.request();
        hasPermission = newPermission.isGranted;
        
        // Check the new status after request
        if (!hasPermission) {
          // Check if it became permanently denied
          final updatedStatus = await Permission.photos.status;
          if (updatedStatus.isPermanentlyDenied) {
            return const Failure('Photo library access was permanently denied. Please enable it in Settings > Privacy & Security > Photos > Coloring Book');
          } else {
            return const Failure('Photo library permission is required to save images. Please allow access when prompted.');
          }
        }
      } else {
        hasPermission = true;
      }
      
      // Double-check we have permission before proceeding
      if (!hasPermission) {
        return const Failure('Photo library permission denied. Please allow access to save your coloring pages.');
      }

      // Generate PNG bytes using the same rendering as export
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Use same paint settings as canvas for pixel-perfect export
      final colorPaint = Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false;

      final linePaint = Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false
        ..blendMode = BlendMode.multiply;

      final srcRect = Rect.fromLTWH(
        0,
        0,
        outlineLayer.width.toDouble(),
        outlineLayer.height.toDouble(),
      );

      final dstRect = srcRect; // 1:1 export size

      // PASS 1: Draw color layer
      canvas.drawImageRect(colorLayer, srcRect, dstRect, colorPaint);

      // PASS 2: Draw freehand strokes
      for (final stroke in strokes) {
        final strokePaint = Paint()
          ..color = stroke.color
          ..strokeWidth = stroke.strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..filterQuality = FilterQuality.none
          ..isAntiAlias = true;
        
        if (stroke.points.length < 2) {
          canvas.drawPoints(ui.PointMode.points, stroke.points, strokePaint);
        } else {
          for (var i = 1; i < stroke.points.length; i++) {
            canvas.drawLine(stroke.points[i - 1], stroke.points[i], strokePaint);
          }
        }
      }

      // PASS 3: Draw line art layer
      canvas.drawImageRect(outlineLayer, srcRect, dstRect, linePaint);

      // Convert to PNG bytes
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        outlineLayer.width,
        outlineLayer.height,
      );
      
      // Validate the generated image
      if (image.width <= 0 || image.height <= 0) {
        return const Failure('Generated image has invalid dimensions');
      }
      
      final pngBytes = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (pngBytes == null) {
        return const Failure('Failed to convert image to PNG format');
      }
      
      // Validate PNG data
      final bytesLength = pngBytes.lengthInBytes;
      if (bytesLength <= 0) {
        return const Failure('Generated PNG data is empty');
      }
      
      // Dispose of the image to free memory
      image.dispose();

      // Save to photo library with better error handling
      try {
        final result = await ImageGallerySaver.saveImage(
          pngBytes.buffer.asUint8List(),
          name: "ColoringPage_${DateTime.now().millisecondsSinceEpoch}",
          quality: 100,
        );

        // Check if result is null or malformed
        if (result == null) {
          return const Failure('Photo library save failed: No response from image gallery saver');
        }

        // Handle boolean result (some versions return bool directly)
        if (result is bool) {
          if (result) {
            return const Success(null);
          } else {
            return const Failure('Failed to save to photo library. Please check permissions and try again.');
          }
        }

        // Handle map result
        if (result is Map) {
          final isSuccess = result['isSuccess'];
          if (isSuccess == true) {
            return const Success(null);
          } else {
            final errorMsg = result['errorMessage']?.toString() ?? 'Unknown error occurred';
            return Failure('Failed to save to photo library: $errorMsg');
          }
        }

        // Fallback for unexpected result format
        return Failure('Unexpected response from photo library: ${result.toString()}');
        
      } catch (galleryError) {
        // Handle ImageGallerySaver specific errors
        final errorMessage = galleryError.toString();
        if (errorMessage.contains('permission') || errorMessage.contains('access')) {
          return const Failure('Photo library permission error. Please ensure the app has photo library access permission in Settings.');
        } else {
          return Failure('Failed to save to photo library: $errorMessage');
        }
      }
    } catch (e) {
      return Failure('Failed to save to photo library: ${e.toString()}');
    }
  }
}
