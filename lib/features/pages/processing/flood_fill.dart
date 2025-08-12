import 'dart:typed_data';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../data/coloring_page.dart';

class FloodFillService {
  static const int _lineThreshold = 50;
  
  static Uint8List? floodFill({
    required Uint8List colorLayerBytes,
    required Uint8List outlineBytes,
    required int x,
    required int y,
    required Color fillColor,
    required int imageWidth,
    required int imageHeight,
  }) {
    try {
      img.Image? colorLayer = img.decodeImage(colorLayerBytes);
      img.Image? outlineImage = img.decodeImage(outlineBytes);
      
      if (colorLayer == null || outlineImage == null) return null;
      
      if (x < 0 || y < 0 || x >= imageWidth || y >= imageHeight) return null;
      
      final outlinePixel = outlineImage.getPixel(x, y);
      final outlineLuminance = img.getLuminance(outlinePixel);
      if (outlineLuminance <= _lineThreshold) return null;
      
      final targetPixel = colorLayer.getPixel(x, y);
      final newColor = img.ColorRgba8(
        fillColor.red,
        fillColor.green,
        fillColor.blue,
        fillColor.alpha,
      );
      
      if (_colorsEqual(targetPixel, newColor)) return null;
      
      _scanlineFill(colorLayer, outlineImage, x, y, targetPixel, newColor);
      
      return Uint8List.fromList(img.encodePng(colorLayer));
    } catch (e) {
      return null;
    }
  }
  
  static void _scanlineFill(
    img.Image colorLayer,
    img.Image outlineImage,
    int startX,
    int startY,
    img.Color targetColor,
    img.Color newColor,
  ) {
    final stack = Queue<Point>();
    stack.add(Point(startX, startY));
    
    while (stack.isNotEmpty) {
      final point = stack.removeFirst();
      int x = point.x;
      int y = point.y;
      
      if (x < 0 || x >= colorLayer.width || y < 0 || y >= colorLayer.height) {
        continue;
      }
      
      final outlinePixel = outlineImage.getPixel(x, y);
      final outlineLuminance = img.getLuminance(outlinePixel);
      if (outlineLuminance <= _lineThreshold) continue;
      
      final currentPixel = colorLayer.getPixel(x, y);
      if (!_colorsEqual(currentPixel, targetColor)) continue;
      
      int x1 = x;
      while (x1 >= 0) {
        final outlineCheck = outlineImage.getPixel(x1, y);
        final outlineCheckLuminance = img.getLuminance(outlineCheck);
        if (outlineCheckLuminance <= _lineThreshold) break;
        
        final colorCheck = colorLayer.getPixel(x1, y);
        if (!_colorsEqual(colorCheck, targetColor)) break;
        
        x1--;
      }
      x1++;
      
      int x2 = x;
      while (x2 < colorLayer.width) {
        final outlineCheck = outlineImage.getPixel(x2, y);
        final outlineCheckLuminance = img.getLuminance(outlineCheck);
        if (outlineCheckLuminance <= _lineThreshold) break;
        
        final colorCheck = colorLayer.getPixel(x2, y);
        if (!_colorsEqual(colorCheck, targetColor)) break;
        
        x2++;
      }
      x2--;
      
      for (int i = x1; i <= x2; i++) {
        colorLayer.setPixel(i, y, newColor);
      }
      
      for (int i = x1; i <= x2; i++) {
        if (y > 0) {
          final upOutlinePixel = outlineImage.getPixel(i, y - 1);
          final upOutlineLuminance = img.getLuminance(upOutlinePixel);
          if (upOutlineLuminance > _lineThreshold) {
            final upPixel = colorLayer.getPixel(i, y - 1);
            if (_colorsEqual(upPixel, targetColor)) {
              stack.add(Point(i, y - 1));
            }
          }
        }
        
        if (y < colorLayer.height - 1) {
          final downOutlinePixel = outlineImage.getPixel(i, y + 1);
          final downOutlineLuminance = img.getLuminance(downOutlinePixel);
          if (downOutlineLuminance > _lineThreshold) {
            final downPixel = colorLayer.getPixel(i, y + 1);
            if (_colorsEqual(downPixel, targetColor)) {
              stack.add(Point(i, y + 1));
            }
          }
        }
      }
    }
  }
  
  static bool _colorsEqual(img.Color a, img.Color b) {
    return a.r == b.r && a.g == b.g && a.b == b.b && a.a == b.a;
  }
  
  static UndoRedoAction createUndoAction({
    required Uint8List beforeBytes,
    required Uint8List afterBytes,
    required int x,
    required int y,
  }) {
    try {
      img.Image? beforeImage = img.decodeImage(beforeBytes);
      img.Image? afterImage = img.decodeImage(afterBytes);
      
      if (beforeImage == null || afterImage == null) {
        return UndoRedoAction(x: x, y: y, pixels: []);
      }
      
      final List<int> changedPixels = [];
      
      for (int py = 0; py < beforeImage.height; py++) {
        for (int px = 0; px < beforeImage.width; px++) {
          final beforePixel = beforeImage.getPixel(px, py);
          final afterPixel = afterImage.getPixel(px, py);
          
          if (!_colorsEqual(beforePixel, afterPixel)) {
            changedPixels.addAll([
              px,
              py,
              beforePixel.r.toInt(),
              beforePixel.g.toInt(),
              beforePixel.b.toInt(),
              beforePixel.a.toInt(),
            ]);
          }
        }
      }
      
      return UndoRedoAction(x: x, y: y, pixels: changedPixels);
    } catch (e) {
      return UndoRedoAction(x: x, y: y, pixels: []);
    }
  }
  
  static Uint8List? applyUndoAction(
    Uint8List imageBytes,
    UndoRedoAction action,
  ) {
    try {
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return null;
      
      for (int i = 0; i < action.pixels.length; i += 6) {
        final x = action.pixels[i];
        final y = action.pixels[i + 1];
        final r = action.pixels[i + 2];
        final g = action.pixels[i + 3];
        final b = action.pixels[i + 4];
        final a = action.pixels[i + 5];
        
        if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
          image.setPixel(x, y, img.ColorRgba8(r, g, b, a));
        }
      }
      
      return Uint8List.fromList(img.encodePng(image));
    } catch (e) {
      return null;
    }
  }
  
  static Uint8List createEmptyColorLayer(int width, int height) {
    final image = img.Image(
      width: width,
      height: height,
      numChannels: 4,
    );
    
    img.fill(image, color: img.ColorRgba8(255, 255, 255, 0));
    
    return Uint8List.fromList(img.encodePng(image));
  }
}

class Point {
  final int x;
  final int y;
  
  const Point(this.x, this.y);
}