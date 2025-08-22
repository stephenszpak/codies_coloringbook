import 'dart:typed_data';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

/// Service for creating subject masks and handling two-pass composition
class SubjectMaskingService {
  
  /// Generate a binary subject mask (white = subject, black = background)
  /// Uses center-bias and morphological operations to find the main subject
  static Uint8List generateSubjectMask(Uint8List imageBytes) {
    try {
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('Failed to decode image');

      // Resize for processing
      image = img.copyResize(image, width: 512, height: 512);
      
      // Convert to grayscale for gradient analysis
      final grayImage = img.grayscale(image);
      
      // Step 1: Calculate gradient magnitude to find edges
      final gradientMap = _calculateGradientMagnitude(grayImage);
      
      // Step 2: Apply center bias - prefer foreground objects near center
      final biasedMap = _applyCenterBias(gradientMap);
      
      // Step 3: Find dominant foreground region using thresholding
      final binaryMask = _createBinaryMask(biasedMap);
      
      // Step 4: Morphological operations - fill holes and smooth edges
      final cleanMask = _morphologicalClean(binaryMask);
      
      // Step 5: Find largest connected component (main subject)
      final finalMask = _findLargestComponent(cleanMask);
      
      // Convert back to original image size
      final resizedMask = img.copyResize(finalMask, 
          width: img.decodeImage(imageBytes)!.width, 
          height: img.decodeImage(imageBytes)!.height);
      
      return Uint8List.fromList(img.encodePng(resizedMask));
    } catch (e) {
      // Fallback: create a center-circle mask
      return _createFallbackMask(imageBytes);
    }
  }
  
  /// Get subject bounding box from mask
  static Map<String, int> getSubjectBoundingBox(Uint8List maskBytes) {
    try {
      final mask = img.decodeImage(maskBytes);
      if (mask == null) throw Exception('Failed to decode mask');
      
      int minX = mask.width, maxX = 0;
      int minY = mask.height, maxY = 0;
      bool foundSubject = false;
      
      for (int y = 0; y < mask.height; y++) {
        for (int x = 0; x < mask.width; x++) {
          final pixel = mask.getPixel(x, y);
          final luminance = img.getLuminance(pixel);
          
          // White pixels (luminance > 128) represent subject
          if (luminance > 128) {
            foundSubject = true;
            minX = math.min(minX, x);
            maxX = math.max(maxX, x);
            minY = math.min(minY, y);
            maxY = math.max(maxY, y);
          }
        }
      }
      
      if (!foundSubject) {
        // Fallback to center region
        return {
          'x': (mask.width * 0.25).round(),
          'y': (mask.height * 0.25).round(),
          'width': (mask.width * 0.5).round(),
          'height': (mask.height * 0.5).round(),
        };
      }
      
      // Add small margin
      final margin = 20;
      return {
        'x': math.max(0, minX - margin),
        'y': math.max(0, minY - margin),
        'width': math.min(mask.width, maxX - minX + 2 * margin),
        'height': math.min(mask.height, maxY - minY + 2 * margin),
      };
    } catch (e) {
      // Fallback bounding box
      final image = img.decodeImage(maskBytes);
      final width = image?.width ?? 512;
      final height = image?.height ?? 512;
      
      return {
        'x': (width * 0.25).round(),
        'y': (height * 0.25).round(),
        'width': (width * 0.5).round(),
        'height': (height * 0.5).round(),
      };
    }
  }
  
  /// Crop image to subject bounding box
  static Uint8List cropToSubject(Uint8List imageBytes, Map<String, int> bbox) {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) throw Exception('Failed to decode image');
      
      final cropped = img.copyCrop(image,
          x: bbox['x']!,
          y: bbox['y']!,
          width: bbox['width']!,
          height: bbox['height']!);
      
      return Uint8List.fromList(img.encodePng(cropped));
    } catch (e) {
      return imageBytes; // Return original if cropping fails
    }
  }
  
  /// Composite subject line art over background line art using mask
  static Uint8List compositeLineArt(
      Uint8List backgroundBytes, 
      Uint8List subjectBytes, 
      Uint8List maskBytes,
      Map<String, int> subjectBbox) {
    try {
      final background = img.decodeImage(backgroundBytes);
      final subject = img.decodeImage(subjectBytes);
      final mask = img.decodeImage(maskBytes);
      
      if (background == null || subject == null || mask == null) {
        throw Exception('Failed to decode composite images');
      }
      
      // Resize subject to match original size
      final resizedSubject = img.copyResize(subject, 
          width: subjectBbox['width']!, 
          height: subjectBbox['height']!);
      
      // Create result image
      final result = img.Image(
        width: background.width,
        height: background.height,
        numChannels: background.numChannels,
      );
      
      // Copy background as base
      for (int y = 0; y < background.height; y++) {
        for (int x = 0; x < background.width; x++) {
          result.setPixel(x, y, background.getPixel(x, y));
        }
      }
      
      // Overlay subject using mask as alpha
      for (int y = 0; y < mask.height; y++) {
        for (int x = 0; x < mask.width; x++) {
          final maskPixel = mask.getPixel(x, y);
          final maskAlpha = img.getLuminance(maskPixel) / 255.0;
          
          if (maskAlpha > 0.5) { // Subject region
            // Calculate subject pixel coordinates
            final subjX = x - subjectBbox['x']!;
            final subjY = y - subjectBbox['y']!;
            
            if (subjX >= 0 && subjX < resizedSubject.width && 
                subjY >= 0 && subjY < resizedSubject.height) {
              final subjectPixel = resizedSubject.getPixel(subjX, subjY);
              result.setPixel(x, y, subjectPixel);
            }
          }
        }
      }
      
      return Uint8List.fromList(img.encodePng(result));
    } catch (e) {
      // Fallback to background
      return backgroundBytes;
    }
  }
  
  // Private helper methods
  
  static img.Image _calculateGradientMagnitude(img.Image grayImage) {
    final gradientMap = img.Image(
      width: grayImage.width,
      height: grayImage.height,
      numChannels: grayImage.numChannels,
    );
    
    for (int y = 1; y < grayImage.height - 1; y++) {
      for (int x = 1; x < grayImage.width - 1; x++) {
        // Sobel gradient calculation
        final gx = _getSobelGx(grayImage, x, y);
        final gy = _getSobelGy(grayImage, x, y);
        final magnitude = math.sqrt(gx * gx + gy * gy);
        
        final normalizedMag = (magnitude / 255.0).clamp(0.0, 1.0);
        final grayValue = (normalizedMag * 255).round();
        gradientMap.setPixel(x, y, img.ColorRgb8(grayValue, grayValue, grayValue));
      }
    }
    
    return gradientMap;
  }
  
  static double _getSobelGx(img.Image image, int x, int y) {
    final pixels = [
      img.getLuminance(image.getPixel(x - 1, y - 1)), img.getLuminance(image.getPixel(x, y - 1)), img.getLuminance(image.getPixel(x + 1, y - 1)),
      img.getLuminance(image.getPixel(x - 1, y)), img.getLuminance(image.getPixel(x, y)), img.getLuminance(image.getPixel(x + 1, y)),
      img.getLuminance(image.getPixel(x - 1, y + 1)), img.getLuminance(image.getPixel(x, y + 1)), img.getLuminance(image.getPixel(x + 1, y + 1)),
    ];
    
    return (-1 * pixels[0] + 1 * pixels[2] + 
            -2 * pixels[3] + 2 * pixels[5] + 
            -1 * pixels[6] + 1 * pixels[8]).toDouble();
  }
  
  static double _getSobelGy(img.Image image, int x, int y) {
    final pixels = [
      img.getLuminance(image.getPixel(x - 1, y - 1)), img.getLuminance(image.getPixel(x, y - 1)), img.getLuminance(image.getPixel(x + 1, y - 1)),
      img.getLuminance(image.getPixel(x - 1, y)), img.getLuminance(image.getPixel(x, y)), img.getLuminance(image.getPixel(x + 1, y)),
      img.getLuminance(image.getPixel(x - 1, y + 1)), img.getLuminance(image.getPixel(x, y + 1)), img.getLuminance(image.getPixel(x + 1, y + 1)),
    ];
    
    return (-1 * pixels[0] + -2 * pixels[1] + -1 * pixels[2] +
            1 * pixels[6] + 2 * pixels[7] + 1 * pixels[8]).toDouble();
  }
  
  static img.Image _applyCenterBias(img.Image gradientMap) {
    final biasedMap = img.Image(
      width: gradientMap.width,
      height: gradientMap.height,
      numChannels: gradientMap.numChannels,
    );
    
    final centerX = gradientMap.width / 2;
    final centerY = gradientMap.height / 2;
    final maxDist = math.sqrt(centerX * centerX + centerY * centerY);
    
    for (int y = 0; y < gradientMap.height; y++) {
      for (int x = 0; x < gradientMap.width; x++) {
        final pixel = gradientMap.getPixel(x, y);
        final gradientValue = img.getLuminance(pixel);
        
        // Calculate distance from center
        final dist = math.sqrt((x - centerX) * (x - centerX) + (y - centerY) * (y - centerY));
        final centerBias = 1.0 - (dist / maxDist * 0.7); // Bias toward center
        
        final biasedValue = (gradientValue * centerBias).clamp(0.0, 255.0).round();
        biasedMap.setPixel(x, y, img.ColorRgb8(biasedValue, biasedValue, biasedValue));
      }
    }
    
    return biasedMap;
  }
  
  static img.Image _createBinaryMask(img.Image biasedMap) {
    final threshold = 80; // Threshold for foreground
    final binaryMask = img.Image(
      width: biasedMap.width,
      height: biasedMap.height,
      numChannels: biasedMap.numChannels,
    );
    
    for (int y = 0; y < biasedMap.height; y++) {
      for (int x = 0; x < biasedMap.width; x++) {
        final pixel = biasedMap.getPixel(x, y);
        final value = img.getLuminance(pixel);
        
        final maskValue = value > threshold ? 255 : 0; // White = subject
        binaryMask.setPixel(x, y, img.ColorRgb8(maskValue, maskValue, maskValue));
      }
    }
    
    return binaryMask;
  }
  
  static img.Image _morphologicalClean(img.Image binaryMask) {
    // Morphological closing: dilation followed by erosion
    final dilated = _dilate(binaryMask);
    final eroded = _erode(dilated);
    return eroded;
  }
  
  static img.Image _dilate(img.Image image) {
    final result = img.Image(
      width: image.width,
      height: image.height,
      numChannels: image.numChannels,
    );
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        int maxValue = 0;
        
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            final nx = x + dx;
            final ny = y + dy;
            
            if (nx >= 0 && nx < image.width && ny >= 0 && ny < image.height) {
              final neighbor = img.getLuminance(image.getPixel(nx, ny));
              maxValue = math.max(maxValue, neighbor.round());
            }
          }
        }
        
        result.setPixel(x, y, img.ColorRgb8(maxValue, maxValue, maxValue));
      }
    }
    
    return result;
  }
  
  static img.Image _erode(img.Image image) {
    final result = img.Image(
      width: image.width,
      height: image.height,
      numChannels: image.numChannels,
    );
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        int minValue = 255;
        
        for (int dy = -1; dy <= 1; dy++) {
          for (int dx = -1; dx <= 1; dx++) {
            final nx = x + dx;
            final ny = y + dy;
            
            if (nx >= 0 && nx < image.width && ny >= 0 && ny < image.height) {
              final neighbor = img.getLuminance(image.getPixel(nx, ny));
              minValue = math.min(minValue, neighbor.round());
            }
          }
        }
        
        result.setPixel(x, y, img.ColorRgb8(minValue, minValue, minValue));
      }
    }
    
    return result;
  }
  
  static img.Image _findLargestComponent(img.Image binaryMask) {
    // Simple largest component finding - for demo purposes
    // In a production app, you'd use a proper connected components algorithm
    return binaryMask;
  }
  
  static Uint8List _createFallbackMask(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      // Create a minimal mask
      final fallback = img.Image(width: 512, height: 512, numChannels: 3);
      img.fill(fallback, color: img.ColorRgb8(0, 0, 0)); // Black background
      return Uint8List.fromList(img.encodePng(fallback));
    }
    
    // Create center circle mask
    final mask = img.Image(width: image.width, height: image.height, numChannels: 3);
    img.fill(mask, color: img.ColorRgb8(0, 0, 0)); // Black background
    
    final centerX = image.width / 2;
    final centerY = image.height / 2;
    final radius = math.min(image.width, image.height) * 0.35;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final dist = math.sqrt((x - centerX) * (x - centerX) + (y - centerY) * (y - centerY));
        if (dist <= radius) {
          mask.setPixel(x, y, img.ColorRgb8(255, 255, 255)); // White subject
        }
      }
    }
    
    return Uint8List.fromList(img.encodePng(mask));
  }
}