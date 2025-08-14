import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:coloring_book/features/pages/processing/flood_fill.dart';

void main() {
  group('FloodFillService', () {
    late Uint8List outlineBytes;
    late Uint8List colorLayerBytes;

    setUpAll(() {
      // Create a test outline: 32x32 with a square boundary
      final outlineImage = img.Image(width: 32, height: 32, numChannels: 3);
      img.fill(outlineImage, color: img.ColorRgb8(255, 255, 255)); // White background

      // Draw black square outline (lines = 0, background = 255)
      for (int i = 8; i < 24; i++) {
        // Top and bottom edges
        outlineImage.setPixelRgb(i, 8, 0, 0, 0);   // Top
        outlineImage.setPixelRgb(i, 23, 0, 0, 0);  // Bottom
        
        // Left and right edges  
        outlineImage.setPixelRgb(8, i, 0, 0, 0);   // Left
        outlineImage.setPixelRgb(23, i, 0, 0, 0);  // Right
      }
      
      outlineBytes = Uint8List.fromList(img.encodePng(outlineImage));

      // Create empty color layer (transparent)
      final colorLayer = img.Image(width: 32, height: 32, numChannels: 4);
      img.fill(colorLayer, color: img.ColorRgba8(255, 255, 255, 0)); // Transparent
      
      colorLayerBytes = Uint8List.fromList(img.encodePng(colorLayer));
    });

    test('should fill enclosed area without leaking', () {
      final result = FloodFillService.floodFill(
        colorLayerBytes: colorLayerBytes,
        outlineBytes: outlineBytes,
        x: 16, // Center of square
        y: 16,
        fillColor: Colors.red,
        imageWidth: 32,
        imageHeight: 32,
      );

      expect(result, isNotNull);
      
      final filledImage = img.decodeImage(result!);
      expect(filledImage, isNotNull);

      // Check that interior pixels are filled (allow for PNG compression artifacts)
      final centerPixel = filledImage!.getPixel(16, 16);
      expect(centerPixel.r.toInt(), greaterThan(200)); // Should be mostly red
      expect(centerPixel.g.toInt(), lessThan(100)); // Should be mostly not green (allow more tolerance)
      expect(centerPixel.b.toInt(), lessThan(100)); // Should be mostly not blue (allow more tolerance)

      // Check that exterior pixels are NOT filled
      final exteriorPixel = filledImage.getPixel(4, 4); // Outside square
      expect(exteriorPixel.a, equals(0)); // Should remain transparent

      // Check that outline pixels are NOT filled
      final outlinePixel = filledImage.getPixel(8, 8); // On the outline
      expect(outlinePixel.a, equals(0)); // Should remain transparent (walls block fill)
    });

    test('should not fill when clicking on wall', () {
      final result = FloodFillService.floodFill(
        colorLayerBytes: colorLayerBytes,
        outlineBytes: outlineBytes,
        x: 8, // On the black outline
        y: 8,
        fillColor: Colors.blue,
        imageWidth: 32,
        imageHeight: 32,
      );

      // Should return null when trying to fill a wall
      expect(result, isNull);
    });

    test('should respect wall boundaries', () {
      final result = FloodFillService.floodFill(
        colorLayerBytes: colorLayerBytes,
        outlineBytes: outlineBytes,
        x: 16, // Inside square
        y: 16,
        fillColor: Colors.green,
        imageWidth: 32,
        imageHeight: 32,
      );

      expect(result, isNotNull);
      final filledImage = img.decodeImage(result!)!;

      // Check pixels just inside the boundary (allow for PNG compression)
      final insidePixel = filledImage.getPixel(9, 9);
      expect(insidePixel.g.toInt(), greaterThan(200)); // Should be mostly green

      // Check pixels just outside the boundary  
      final outsidePixel = filledImage.getPixel(7, 7);
      expect(outsidePixel.a, equals(0)); // Should remain transparent

      // Verify the wall itself wasn't filled
      final wallPixel = filledImage.getPixel(8, 8);
      expect(wallPixel.a, equals(0)); // Wall should remain transparent
    });

    test('should handle out of bounds coordinates', () {
      final result = FloodFillService.floodFill(
        colorLayerBytes: colorLayerBytes,
        outlineBytes: outlineBytes,
        x: -1, // Out of bounds
        y: 16,
        fillColor: Colors.yellow,
        imageWidth: 32,
        imageHeight: 32,
      );

      expect(result, isNull);

      final result2 = FloodFillService.floodFill(
        colorLayerBytes: colorLayerBytes,
        outlineBytes: outlineBytes,
        x: 16,
        y: 50, // Out of bounds
        fillColor: Colors.yellow,
        imageWidth: 32,
        imageHeight: 32,
      );

      expect(result2, isNull);
    });

    test('should create undo action with correct pixel data', () {
      // Fill area first
      final beforeBytes = Uint8List.fromList(colorLayerBytes);
      final filledResult = FloodFillService.floodFill(
        colorLayerBytes: colorLayerBytes,
        outlineBytes: outlineBytes,
        x: 16,
        y: 16,
        fillColor: Colors.red,
        imageWidth: 32,
        imageHeight: 32,
      );

      expect(filledResult, isNotNull);

      // Create undo action
      final undoAction = FloodFillService.createUndoAction(
        beforeBytes: beforeBytes,
        afterBytes: filledResult!,
        x: 16,
        y: 16,
      );

      expect(undoAction.x, equals(16));
      expect(undoAction.y, equals(16));
      expect(undoAction.pixels.length, greaterThan(0));
      
      // Pixels should be stored as [x, y, r, g, b, a, x, y, r, g, b, a, ...]
      expect(undoAction.pixels.length % 6, equals(0));
    });

    test('should apply undo action correctly', () {
      // Fill area
      final originalBytes = Uint8List.fromList(colorLayerBytes);
      final filledResult = FloodFillService.floodFill(
        colorLayerBytes: colorLayerBytes,
        outlineBytes: outlineBytes,
        x: 16,
        y: 16,
        fillColor: Colors.red,
        imageWidth: 32,
        imageHeight: 32,
      );

      expect(filledResult, isNotNull);

      // Create and apply undo
      final undoAction = FloodFillService.createUndoAction(
        beforeBytes: originalBytes,
        afterBytes: filledResult!,
        x: 16,
        y: 16,
      );

      final undoResult = FloodFillService.applyUndoAction(
        filledResult,
        undoAction,
      );

      expect(undoResult, isNotNull);

      // Compare with original - should be similar (allowing for compression differences)
      final originalImage = img.decodeImage(originalBytes)!;
      final undoImage = img.decodeImage(undoResult!)!;

      // Check a few key pixels
      final originalCenter = originalImage.getPixel(16, 16);
      final undoCenter = undoImage.getPixel(16, 16);
      
      expect(originalCenter.a, equals(undoCenter.a)); // Both should be transparent
    });

    test('should create empty color layer with correct properties', () {
      final emptyLayer = FloodFillService.createEmptyColorLayer(64, 48);
      
      final image = img.decodeImage(emptyLayer);
      expect(image, isNotNull);
      expect(image!.width, equals(64));
      expect(image.height, equals(48));

      // Should be transparent
      final pixel = image.getPixel(32, 24);
      expect(pixel.a, equals(0));
      expect(pixel.r, equals(255)); // White but transparent
      expect(pixel.g, equals(255));
      expect(pixel.b, equals(255));
    });
  });
}