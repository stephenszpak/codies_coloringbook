import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import '../core/result.dart';
import '../config/api_config.dart';
import '../features/pages/ui/create_page_screen.dart';

class OpenAIBackend {
  static const String _baseUrl = 'https://api.openai.com/v1';
  final Dio _dio = Dio();
  String? _cachedApiKey;

  /// Get the API key from .env file
  String? _getApiKey() {
    _cachedApiKey ??= ApiConfig.getOpenAIApiKey();
    return _cachedApiKey;
  }

  Future<Result<Uint8List>> photoToLineArt(
    Uint8List imageBytes, 
    int outlineStrength, {
    ArtStyle artStyle = ArtStyle.cartoon,
  }) async {
    try {
      final apiKey = _getApiKey();
      if (apiKey == null || !ApiConfig.isValidApiKey(apiKey)) {
        return const Failure('OpenAI API key not configured or invalid. Please check your .env file.');
      }

      // Handle exact trace mode with local edge detection
      if (artStyle == ArtStyle.exactTrace) {
        return await _processExactTrace(imageBytes);
      }

      // For other modes, use AI processing
      final base64Image = base64.encode(imageBytes);
      
      // Use standard vision analysis
      final visionModel = 'gpt-4o-mini';
      final maxTokens = 300;
      
      final visionResponse = await _dio.post(
        '$_baseUrl/chat/completions',
        data: {
          'model': visionModel,
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': _getVisionPrompt(artStyle)
                },
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/png;base64,$base64Image'
                  }
                }
              ]
            }
          ],
          'max_tokens': maxTokens
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (visionResponse.statusCode != 200) {
        return Failure('Vision API error: ${visionResponse.statusCode}');
      }

      final description = visionResponse.data['choices'][0]['message']['content'] as String;
      
      // Standard processing for cartoon and realistic modes
      final prompt = _getPhotoToLineArtPrompt(description, artStyle);
      return await _generateImageFromPrompt(prompt);
      
    } on DioException catch (e) {
      return Failure('Network error: ${e.message}');
    } catch (e) {
      return Failure('Unexpected error: ${e.toString()}');
    }
  }

  Future<Result<Uint8List>> promptToLineArt(
    String userPrompt, {
    ArtStyle artStyle = ArtStyle.cartoon,
  }) async {
    try {
      final apiKey = _getApiKey();
      if (apiKey == null || !ApiConfig.isValidApiKey(apiKey)) {
        return const Failure('OpenAI API key not configured or invalid. Please check your .env file.');
      }

      final prompt = _getPromptToLineArtPrompt(userPrompt, artStyle);

      final response = await _dio.post(
        '$_baseUrl/images/generations',
        data: {
          'model': 'dall-e-3',
          'prompt': prompt,
          'n': 1,
          'size': '1024x1024',
          'response_format': 'b64_json',
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['data'] != null && data['data'].isNotEmpty) {
          final b64Image = data['data'][0]['b64_json'];
          final imageBytes = base64.decode(b64Image);
          final processedBytes = await _postProcessImage(imageBytes);
          return Success(processedBytes);
        } else {
          return const Failure('No image data returned from OpenAI');
        }
      } else {
        return Failure('OpenAI API error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      return Failure('Network error: ${e.message}');
    } catch (e) {
      return Failure('Unexpected error: ${e.toString()}');
    }
  }

  Future<Result<void>> healthCheck() async {
    try {
      final apiKey = _getApiKey();
      if (apiKey == null || !ApiConfig.isValidApiKey(apiKey)) {
        return const Failure('OpenAI API key not configured or invalid. Please check your .env file.');
      }

      final response = await _dio.get(
        '$_baseUrl/models',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
          },
        ),
      );

      if (response.statusCode == 200) {
        return const Success(null);
      } else {
        return Failure('API key validation failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return const Failure('Invalid API key');
      }
      return Failure('Connection error: ${e.message}');
    } catch (e) {
      return Failure('Unexpected error: ${e.toString()}');
    }
  }

  Future<String> _loadPromptTemplate(String templateName) async {
    try {
      final file = File('lib/ai/prompts/$templateName.md');
      if (await file.exists()) {
        return await file.readAsString();
      } else {
        switch (templateName) {
          case 'photo_to_line_art':
            return 'Create a detailed black and white coloring page that accurately recreates this photo: {description}. Preserve all important details, objects, people, animals, backgrounds, and proportions exactly as described. Convert to clean black outlines on pure white background with continuous, closed regions perfect for coloring. Include all elements from the original photo - faces, clothing details, background objects, textures, and spatial relationships. Make lines thick enough for easy coloring (thickness: {outlineStrength}/100 strength) but preserve the photo\'s composition and details. No color, no shading, no text - just accurate black line art of the complete scene.';
          case 'prompt_to_line_art':
            return 'Create a simple black and white coloring page featuring ONLY a single {userPrompt}. Draw just one main subject - no background, no decorations, no additional objects, no patterns, no circles, no borders, no extra elements. Pure white background with only bold black outlines of the single requested subject. Make it large, simple, and centered with thick continuous lines and completely closed regions for easy coloring. No details, no shading, no color, no text - just the one requested subject as a clean line drawing.';
          default:
            return 'Create a simple black and white coloring page with thick lines for a 4-year-old child.';
        }
      }
    } catch (e) {
      return 'Create a simple coloring book page.';
    }
  }

  Future<Uint8List> _postProcessImage(Uint8List imageBytes) async {
    try {
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return imageBytes;

      image = img.copyResize(image, width: 2048, height: 2048);

      // First pass: Aggressive gradient removal - only very dark pixels become black
      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final luminance = img.getLuminance(pixel);
          
          // More aggressive threshold - only very dark areas (< 80) become black lines
          // This helps eliminate gradients and gray shading
          final newPixel = luminance < 80
              ? img.ColorRgb8(0, 0, 0)
              : img.ColorRgb8(255, 255, 255);
          
          image.setPixel(x, y, newPixel);
        }
      }

      // Second pass: Clean up isolated pixels to reduce noise
      image = _cleanupIsolatedPixels(image);

      // Third pass: Simple dilation to thicken lines
      image = _dilateImage(image);

      return Uint8List.fromList(img.encodePng(image));
    } catch (e) {
      return imageBytes;
    }
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

  img.Image _cleanupIsolatedPixels(img.Image image) {
    final cleaned = img.Image(
      width: image.width,
      height: image.height,
      numChannels: image.numChannels,
    );

    // Copy original image first
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        cleaned.setPixel(x, y, image.getPixel(x, y));
      }
    }

    // Remove isolated black pixels (noise reduction)
    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        final pixel = image.getPixel(x, y);
        final luminance = img.getLuminance(pixel);
        
        if (luminance < 128) { // If it's a black pixel
          // Count black neighbors
          int blackNeighbors = 0;
          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              if (dx == 0 && dy == 0) continue;
              final neighborPixel = image.getPixel(x + dx, y + dy);
              final neighborLuminance = img.getLuminance(neighborPixel);
              if (neighborLuminance < 128) {
                blackNeighbors++;
              }
            }
          }
          
          // If isolated (less than 2 black neighbors), remove it
          if (blackNeighbors < 2) {
            cleaned.setPixel(x, y, img.ColorRgb8(255, 255, 255));
          }
        }
      }
    }

    return cleaned;
  }

  /// Get vision prompt based on art style
  String _getVisionPrompt(ArtStyle artStyle) {
    switch (artStyle) {
      case ArtStyle.cartoon:
        return 'Describe this image in complete detail for creating a cartoon-style coloring page. Include all people, animals, objects, clothing, facial features, background elements, poses, expressions, and spatial relationships. Focus on simplified shapes and kid-friendly features. Describe textures, patterns, and important details that should be preserved in the coloring page. Be thorough and specific about the entire scene composition, proportions, and layout.';
      case ArtStyle.realistic:
        return 'Describe this image in complete detail for creating a realistic LINE ART coloring page. Include all people, animals, objects, clothing, facial features, background elements, poses, expressions, and spatial relationships. Preserve accurate proportions, anatomical details, and realistic features. Focus on OUTLINES and CONTOURS only - describe the shapes and boundaries that should be drawn as black lines. Be thorough about the scene composition and realistic layout, but emphasize line-drawable elements only.';
      case ArtStyle.exactTrace:
        return 'This will be processed using local edge detection - provide a basic scene description for fallback processing: main subjects, approximate positions, and key identifying features.';
    }
  }

  /// Get photo-to-line-art prompt based on art style
  String _getPhotoToLineArtPrompt(String description, ArtStyle artStyle) {
    switch (artStyle) {
      case ArtStyle.cartoon:
        return 'Create a black and white coloring page based on this description: $description. '
               'Use cartoon style with simplified shapes, kid-friendly features, medium-thick continuous outlines, '
               'no shading, no gray areas, pure white background, and closed regions suitable for tap-to-fill coloring. '
               'Make shapes bold and forgiving for children to color.';
      case ArtStyle.realistic:
        return 'Create a black and white coloring page based on this description: $description. '
               'IMPORTANT: Use ONLY pure black lines on pure white background - absolutely NO gradients, NO gray shading, NO shadows, NO textures. '
               'Preserve realistic proportions and fine structure with simple continuous black outlines only. '
               'Draw clean line art with consistent black outlines, completely white interior areas ready for coloring. '
               'Emphasize accurate contours and important details using ONLY black lines - no fill patterns or shading.';
      case ArtStyle.exactTrace:
        // This mode will use local edge detection, but we provide a fallback prompt
        return 'Create a precise line art tracing based on this description: $description. '
               'Use ONLY pure black outlines on white background with exact geometric accuracy and minimal stylistic interpretation. '
               'Preserve all proportions and spatial relationships exactly as described.';
    }
  }

  /// Get prompt-to-line-art prompt based on art style
  String _getPromptToLineArtPrompt(String userPrompt, ArtStyle artStyle) {
    switch (artStyle) {
      case ArtStyle.cartoon:
        return 'Create a black and white coloring page of $userPrompt. '
               'Use cartoon style with kid-friendly features, simplified shapes, medium-thick continuous outlines, '
               'no shading, no gray areas, pure white background, and closed regions suitable for coloring. '
               'Make it bold and appealing for children.';
      case ArtStyle.realistic:
        return 'Create a black and white coloring page depicting $userPrompt with realistic proportions and recognizable anatomy/geometry. '
               'CRITICAL: Use ONLY pure black outlines on pure white background - NO gradients, NO gray areas, NO shading, NO shadows, NO fill patterns. '
               'Draw realistic proportions using simple continuous black lines only, with completely white interior areas ready for coloring. '
               'Avoid caricature; retain accurate features while ensuring all regions are outlined in solid black lines with closed boundaries.';
      case ArtStyle.exactTrace:
        // Not applicable for text prompts - fallback to realistic
        return 'Create a black and white coloring page depicting $userPrompt with realistic proportions and recognizable anatomy/geometry. '
               'CRITICAL: Use ONLY pure black outlines on pure white background - NO gradients, NO gray areas, NO shading, NO shadows, NO fill patterns. '
               'Draw realistic proportions using simple continuous black lines only, with completely white interior areas ready for coloring. '
               'Avoid caricature; retain accurate features while ensuring all regions are outlined in solid black lines with closed boundaries.';
    }
  }

  /// Process Exact Trace mode using local edge detection
  Future<Result<Uint8List>> _processExactTrace(Uint8List imageBytes) async {
    try {
      // Implement Difference of Gaussians (DoG) edge detection
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        return const Failure('Failed to decode input image for edge detection');
      }

      // Resize to standard processing size
      image = img.copyResize(image, width: 1024, height: 1024);

      // Convert to grayscale first
      final grayImage = img.grayscale(image);

      // Apply DoG edge detection
      final edgeImage = _applyDoGEdgeDetection(grayImage);

      // Convert to PNG
      final pngBytes = Uint8List.fromList(img.encodePng(edgeImage));
      return Success(pngBytes);
    } catch (e) {
      return Failure('Exact trace processing failed: ${e.toString()}');
    }
  }


  /// Generate image from DALL-E prompt
  Future<Result<Uint8List>> _generateImageFromPrompt(String prompt) async {
    final apiKey = _getApiKey();
    if (apiKey == null) {
      return const Failure('API key not available');
    }

    final response = await _dio.post(
      '$_baseUrl/images/generations',
      data: {
        'model': 'dall-e-3',
        'prompt': prompt,
        'n': 1,
        'size': '1024x1024',
        'response_format': 'b64_json',
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
      ),
    );

    if (response.statusCode == 200) {
      final data = response.data;
      if (data['data'] != null && data['data'].isNotEmpty) {
        final b64Image = data['data'][0]['b64_json'];
        final imageBytes = base64.decode(b64Image);
        final processedBytes = await _postProcessImage(imageBytes);
        return Success(processedBytes);
      } else {
        return const Failure('No image data returned from OpenAI');
      }
    } else {
      return Failure('OpenAI API error: ${response.statusCode}');
    }
  }

  /// Apply Difference of Gaussians edge detection
  img.Image _applyDoGEdgeDetection(img.Image grayImage) {
    // Create result image
    final result = img.Image(
      width: grayImage.width,
      height: grayImage.height,
      numChannels: grayImage.numChannels,
    );

    // Simple edge detection using gradients
    for (int y = 1; y < grayImage.height - 1; y++) {
      for (int x = 1; x < grayImage.width - 1; x++) {
        // Calculate gradients using Sobel operators
        final gx = _getSobelGx(grayImage, x, y);
        final gy = _getSobelGy(grayImage, x, y);
        
        // Calculate magnitude
        final magnitude = math.sqrt(gx * gx + gy * gy);
        
        // Threshold to create binary edge map
        final edgeStrength = magnitude > 50 ? 0 : 255; // Black edges on white background
        result.setPixel(x, y, img.ColorRgb8(edgeStrength, edgeStrength, edgeStrength));
      }
    }

    // Fill borders
    for (int x = 0; x < grayImage.width; x++) {
      result.setPixel(x, 0, img.ColorRgb8(255, 255, 255));
      result.setPixel(x, grayImage.height - 1, img.ColorRgb8(255, 255, 255));
    }
    for (int y = 0; y < grayImage.height; y++) {
      result.setPixel(0, y, img.ColorRgb8(255, 255, 255));
      result.setPixel(grayImage.width - 1, y, img.ColorRgb8(255, 255, 255));
    }

    return result;
  }

  /// Calculate Sobel Gx gradient
  double _getSobelGx(img.Image image, int x, int y) {
    final pixels = [
      img.getLuminance(image.getPixel(x - 1, y - 1)), img.getLuminance(image.getPixel(x, y - 1)), img.getLuminance(image.getPixel(x + 1, y - 1)),
      img.getLuminance(image.getPixel(x - 1, y)), img.getLuminance(image.getPixel(x, y)), img.getLuminance(image.getPixel(x + 1, y)),
      img.getLuminance(image.getPixel(x - 1, y + 1)), img.getLuminance(image.getPixel(x, y + 1)), img.getLuminance(image.getPixel(x + 1, y + 1)),
    ];
    
    return (-1 * pixels[0] + 1 * pixels[2] + 
            -2 * pixels[3] + 2 * pixels[5] + 
            -1 * pixels[6] + 1 * pixels[8]).toDouble();
  }

  /// Calculate Sobel Gy gradient
  double _getSobelGy(img.Image image, int x, int y) {
    final pixels = [
      img.getLuminance(image.getPixel(x - 1, y - 1)), img.getLuminance(image.getPixel(x, y - 1)), img.getLuminance(image.getPixel(x + 1, y - 1)),
      img.getLuminance(image.getPixel(x - 1, y)), img.getLuminance(image.getPixel(x, y)), img.getLuminance(image.getPixel(x + 1, y)),
      img.getLuminance(image.getPixel(x - 1, y + 1)), img.getLuminance(image.getPixel(x, y + 1)), img.getLuminance(image.getPixel(x + 1, y + 1)),
    ];
    
    return (-1 * pixels[0] + -2 * pixels[1] + -1 * pixels[2] +
            1 * pixels[6] + 2 * pixels[7] + 1 * pixels[8]).toDouble();
  }

}