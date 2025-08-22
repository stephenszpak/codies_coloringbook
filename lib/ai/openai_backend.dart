import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import '../core/result.dart';
import '../config/api_config.dart';
import '../features/pages/ui/create_page_screen.dart';
import 'subject_masking.dart';

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
    bool useCharacterizer = false,
    double backgroundDetail = 0.2,
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

      // Handle characterizer mode with two-pass composition
      if (useCharacterizer) {
        return await _processCharacterizer(imageBytes, artStyle, backgroundDetail);
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

  /// Process characterizer mode with two-pass composition
  Future<Result<Uint8List>> _processCharacterizer(
      Uint8List imageBytes, ArtStyle artStyle, double backgroundDetail) async {
    try {
      // Step 1: Generate subject mask
      final maskBytes = SubjectMaskingService.generateSubjectMask(imageBytes);
      
      // Step 2: Get subject bounding box
      final subjectBbox = SubjectMaskingService.getSubjectBoundingBox(maskBytes);
      
      // Step 3: Background pass - generate simplified background line art
      final backgroundResult = await _generateBackgroundLineArt(imageBytes, artStyle, backgroundDetail);
      if (backgroundResult.isFailure) return backgroundResult;
      
      // Step 4: Subject pass - crop and generate high-fidelity subject line art
      final subjectCropBytes = SubjectMaskingService.cropToSubject(imageBytes, subjectBbox);
      final subjectResult = await _generateSubjectLineArt(subjectCropBytes, artStyle);
      if (subjectResult.isFailure) return subjectResult;
      
      // Step 5: Composite subject over background using mask
      final compositeBytes = SubjectMaskingService.compositeLineArt(
          backgroundResult.dataOrNull!, 
          subjectResult.dataOrNull!, 
          maskBytes, 
          subjectBbox);
      
      // Step 6: Post-process the composite result
      final finalBytes = await _postProcessCharacterizer(compositeBytes, maskBytes, backgroundDetail);
      
      return Success(finalBytes);
    } catch (e) {
      return Failure('Characterizer processing failed: ${e.toString()}');
    }
  }
  
  /// Generate background line art with simplification
  Future<Result<Uint8List>> _generateBackgroundLineArt(
      Uint8List imageBytes, ArtStyle artStyle, double backgroundDetail) async {
    
    final base64Image = base64.encode(imageBytes);
    
    // Get vision description for background
    final visionResponse = await _dio.post(
      '$_baseUrl/chat/completions',
      data: {
        'model': 'gpt-4o-mini',
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': _getBackgroundVisionPrompt(artStyle, backgroundDetail)
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
        'max_tokens': 200
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer ${_getApiKey()}',
          'Content-Type': 'application/json',
        },
      ),
    );

    if (visionResponse.statusCode != 200) {
      return Failure('Background vision API error: ${visionResponse.statusCode}');
    }

    final description = visionResponse.data['choices'][0]['message']['content'] as String;
    final prompt = _getBackgroundLineArtPrompt(description, artStyle, backgroundDetail);
    
    return await _generateImageFromPrompt(prompt);
  }
  
  /// Generate subject line art with high fidelity
  Future<Result<Uint8List>> _generateSubjectLineArt(
      Uint8List subjectCropBytes, ArtStyle artStyle) async {
    
    // For exact trace, use local processing on subject crop
    if (artStyle == ArtStyle.exactTrace) {
      return await _processExactTrace(subjectCropBytes);
    }
    
    final base64Image = base64.encode(subjectCropBytes);
    
    // Get vision description for subject
    final visionResponse = await _dio.post(
      '$_baseUrl/chat/completions',
      data: {
        'model': 'gpt-4o-mini',
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': _getSubjectVisionPrompt(artStyle)
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
        'max_tokens': 200
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer ${_getApiKey()}',
          'Content-Type': 'application/json',
        },
      ),
    );

    if (visionResponse.statusCode != 200) {
      return Failure('Subject vision API error: ${visionResponse.statusCode}');
    }

    final description = visionResponse.data['choices'][0]['message']['content'] as String;
    final prompt = _getSubjectLineArtPrompt(description, artStyle);
    
    return await _generateImageFromPrompt(prompt);
  }
  
  /// Post-process the composite with different morphology for subject vs background
  Future<Uint8List> _postProcessCharacterizer(
      Uint8List compositeBytes, Uint8List maskBytes, double backgroundDetail) async {
    try {
      final composite = img.decodeImage(compositeBytes);
      final mask = img.decodeImage(maskBytes);
      if (composite == null || mask == null) return compositeBytes;
      
      // Resize composite to match processing size
      final processedComposite = img.copyResize(composite, width: 2048, height: 2048);
      final processedMask = img.copyResize(mask, width: 2048, height: 2048);
      
      // Apply different post-processing to subject vs background regions
      final result = img.Image(
        width: processedComposite.width,
        height: processedComposite.height,
        numChannels: processedComposite.numChannels,
      );
      
      for (int y = 0; y < processedComposite.height; y++) {
        for (int x = 0; x < processedComposite.width; x++) {
          final maskPixel = processedMask.getPixel(x, y);
          final isSubject = img.getLuminance(maskPixel) > 128;
          
          final compositePixel = processedComposite.getPixel(x, y);
          final luminance = img.getLuminance(compositePixel);
          
          // Different thresholds for subject vs background
          final threshold = isSubject ? 70 : (80 + (backgroundDetail * 40)); // Subject preserves more detail
          
          final newPixel = luminance < threshold
              ? img.ColorRgb8(0, 0, 0)
              : img.ColorRgb8(255, 255, 255);
          
          result.setPixel(x, y, newPixel);
        }
      }
      
      // Apply different morphological operations
      final cleanedResult = _morphologicalCleanCharacterizer(result, processedMask, backgroundDetail);
      
      return Uint8List.fromList(img.encodePng(cleanedResult));
    } catch (e) {
      return compositeBytes;
    }
  }
  
  /// Apply morphological operations with different strength for subject vs background
  img.Image _morphologicalCleanCharacterizer(img.Image image, img.Image mask, double backgroundDetail) {
    // For subjects, apply minimal morphology to preserve detail
    // For background, apply stronger morphology based on backgroundDetail setting
    
    final result = img.Image(
      width: image.width,
      height: image.height,
      numChannels: image.numChannels,
    );
    
    // Copy original
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        result.setPixel(x, y, image.getPixel(x, y));
      }
    }
    
    // Apply region-specific morphology
    final backgroundMorphStrength = (1.0 - backgroundDetail * 0.7).clamp(0.3, 1.0);
    
    if (backgroundMorphStrength > 0.5) {
      // Apply stronger morphology to background regions
      for (int y = 1; y < image.height - 1; y++) {
        for (int x = 1; x < image.width - 1; x++) {
          final maskPixel = mask.getPixel(x, y);
          final isSubject = img.getLuminance(maskPixel) > 128;
          
          if (!isSubject) { // Background region
            final pixel = image.getPixel(x, y);
            final luminance = img.getLuminance(pixel);
            
            if (luminance < 128) { // Black pixel (line)
              // Apply dilation to thicken background lines
              for (int dy = -1; dy <= 1; dy++) {
                for (int dx = -1; dx <= 1; dx++) {
                  final nx = x + dx;
                  final ny = y + dy;
                  if (nx >= 0 && nx < image.width && ny >= 0 && ny < image.height) {
                    final neighborMask = mask.getPixel(nx, ny);
                    final neighborIsSubject = img.getLuminance(neighborMask) > 128;
                    
                    if (!neighborIsSubject) { // Only dilate within background
                      result.setPixel(nx, ny, img.ColorRgb8(0, 0, 0));
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    
    return result;
  }
  
  // Vision prompts for characterizer
  
  String _getBackgroundVisionPrompt(ArtStyle artStyle, double backgroundDetail) {
    final detailLevel = backgroundDetail > 0.7 ? 'detailed' : 
                       backgroundDetail > 0.3 ? 'moderate' : 'minimal';
    
    return 'Focus only on the BACKGROUND elements of this image, ignoring the main subject/person/animal. '
           'Describe background objects, scenery, setting, and environment in $detailLevel detail for creating '
           'simplified background line art. Include large shapes, architectural elements, landscape features, '
           'but minimize small textures and clutter. Describe what should be simplified or removed entirely.';
  }
  
  String _getSubjectVisionPrompt(ArtStyle artStyle) {
    return 'Focus only on the MAIN SUBJECT (person, animal, or central object) in this image, ignoring the background. '
           'Describe the subject\'s exact silhouette, proportions, facial features, pose, clothing details, and '
           'important characteristics that must be preserved in high-fidelity line art. Be precise about contours, '
           'anatomy, and distinctive features that define the subject\'s identity and likeness.';
  }
  
  String _getBackgroundLineArtPrompt(String description, ArtStyle artStyle, double backgroundDetail) {
    final simplificationLevel = backgroundDetail > 0.7 ? 'moderate simplification' : 
                                backgroundDetail > 0.3 ? 'significant simplification' : 'minimal detail, maximum simplification';
    
    return 'Create background line art with $simplificationLevel based on: $description. '
           'IMPORTANT: Pure black outlines on white background only. No main subject - just background elements. '
           'Large, simple shapes for background objects. Remove small textures and clutter. '
           'Use continuous black lines with closed regions suitable for coloring. No shading, no gray areas.';
  }
  
  String _getSubjectLineArtPrompt(String description, ArtStyle artStyle) {
    return 'Create high-fidelity line art preserving exact subject likeness based on: $description. '
           'CRITICAL: Preserve exact silhouette, proportions, and fine contours of the subject. '
           'Thin-to-medium continuous black lines on pure white background. Capture all important '
           'facial features, anatomical details, and distinctive characteristics. No background elements. '
           'Maintain subject identity and recognizable features with precise line work and closed regions.';
  }

}