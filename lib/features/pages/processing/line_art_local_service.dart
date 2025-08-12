import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../../../core/result.dart';

class LineArtLocalService {
  static const int _defaultMaxSize = 2048;

  Future<Result<Uint8List>> processImage(
    Uint8List imageBytes, {
    int outlineStrength = 50,
    int maxSize = _defaultMaxSize,
  }) async {
    try {
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        return const Failure('Could not decode image');
      }

      image = _resizeImage(image, maxSize);

      image = img.grayscale(image);

      image = img.gaussianBlur(image, radius: 1);

      image = _applySobelEdgeDetection(image, outlineStrength);

      image = _ensureBlackOnWhite(image);

      image = _dilateImage(image);

      final pngBytes = img.encodePng(image);
      return Success(Uint8List.fromList(pngBytes));
    } catch (e) {
      return Failure('Failed to process image: ${e.toString()}');
    }
  }

  img.Image _resizeImage(img.Image image, int maxSize) {
    final int width = image.width;
    final int height = image.height;
    
    if (width <= maxSize && height <= maxSize) {
      return image;
    }

    if (width > height) {
      final newHeight = (height * maxSize / width).round();
      return img.copyResize(image, width: maxSize, height: newHeight);
    } else {
      final newWidth = (width * maxSize / height).round();
      return img.copyResize(image, width: newWidth, height: maxSize);
    }
  }

  img.Image _applySobelEdgeDetection(img.Image image, int strength) {
    final sobelX = [
      [-1, 0, 1],
      [-2, 0, 2],
      [-1, 0, 1],
    ];

    final sobelY = [
      [-1, -2, -1],
      [0, 0, 0],
      [1, 2, 1],
    ];

    final result = img.Image(
      width: image.width,
      height: image.height,
      numChannels: 1,
    );

    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        double gx = 0;
        double gy = 0;

        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixel = image.getPixel(x + kx, y + ky);
            final intensity = img.getLuminance(pixel).toDouble();
            
            gx += intensity * sobelX[ky + 1][kx + 1];
            gy += intensity * sobelY[ky + 1][kx + 1];
          }
        }

        final magnitude = math.sqrt(gx * gx + gy * gy);
        // Lower threshold = more sensitive to edges (more lines)
        // Higher threshold = less sensitive (fewer, stronger lines)
        final threshold = (50 + (strength * 150 / 100)).toDouble();
        
        final edgeValue = magnitude > threshold ? 0 : 255;
        result.setPixel(x, y, img.ColorRgb8(edgeValue, edgeValue, edgeValue));
      }
    }

    return result;
  }

  img.Image _ensureBlackOnWhite(img.Image image) {
    int blackPixels = 0;
    int whitePixels = 0;
    const sampleSize = 100; // Smaller, more manageable sample
    
    // Sample pixels evenly across the image
    for (int i = 0; i < sampleSize; i++) {
      final x = ((i % 10) * image.width / 10).round();
      final y = ((i ~/ 10) * image.height / 10).round();
      
      if (x < image.width && y < image.height) {
        final pixel = image.getPixel(x, y);
        final luminance = img.getLuminance(pixel);
        
        if (luminance < 128) {
          blackPixels++;
        } else {
          whitePixels++;
        }
      }
    }

    // For line art, we typically want mostly white background with black lines
    // If we have too many black pixels, the image might be inverted
    if (blackPixels > whitePixels * 2) { // More conservative threshold
      return img.invert(image);
    }
    
    return image;
  }

  img.Image _dilateImage(img.Image image) {
    final dilated = img.Image(
      width: image.width,
      height: image.height,
      numChannels: image.numChannels,
    );

    // Copy original image first
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        dilated.setPixel(x, y, image.getPixel(x, y));
      }
    }

    // Dilate black pixels (expand lines)
    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        final pixel = image.getPixel(x, y);
        final luminance = img.getLuminance(pixel);
        
        if (luminance < 128) { // If it's a black pixel (line)
          // Set surrounding pixels to black too
          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              if (dx == 0 && dy == 0) continue;
              final nx = x + dx;
              final ny = y + dy;
              if (nx >= 0 && nx < image.width && ny >= 0 && ny < image.height) {
                final neighborPixel = image.getPixel(nx, ny);
                final neighborLuminance = img.getLuminance(neighborPixel);
                if (neighborLuminance >= 128) { // Only dilate into white areas
                  dilated.setPixel(nx, ny, img.ColorRgb8(0, 0, 0));
                }
              }
            }
          }
        }
      }
    }

    return dilated;
  }
}