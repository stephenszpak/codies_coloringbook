import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import '../core/result.dart';
import '../config/api_config.dart';

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
    int outlineStrength,
  ) async {
    try {
      final apiKey = _getApiKey();
      if (apiKey == null || !ApiConfig.isValidApiKey(apiKey)) {
        return const Failure('OpenAI API key not configured or invalid. Please check your .env file.');
      }

      // For photo-to-line-art, we'll use GPT-4 Vision to describe the image,
      // then use DALL-E 3 to generate a coloring page based on that description
      
      // First, convert image to base64 for vision API
      final base64Image = base64.encode(imageBytes);
      
      // Use GPT-4 Vision to describe the image
      final visionResponse = await _dio.post(
        '$_baseUrl/chat/completions',
        data: {
          'model': 'gpt-4o-mini', // More cost-effective vision model
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text': 'Describe this image in complete detail for creating an accurate coloring page. Include all people, animals, objects, clothing, facial features, background elements, poses, expressions, and spatial relationships. Describe textures, patterns, and important details that should be preserved in the coloring page. Be thorough and specific about the entire scene composition, proportions, and layout.'
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
          'max_tokens': 300
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
      
      // Now use DALL-E 3 to create a coloring page based on the description
      final promptTemplate = await _loadPromptTemplate('photo_to_line_art');
      final prompt = promptTemplate
          .replaceAll('{description}', description)
          .replaceAll('{outlineStrength}', outlineStrength.toString());

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

  Future<Result<Uint8List>> promptToLineArt(
    String userPrompt,
  ) async {
    try {
      final apiKey = _getApiKey();
      if (apiKey == null || !ApiConfig.isValidApiKey(apiKey)) {
        return const Failure('OpenAI API key not configured or invalid. Please check your .env file.');
      }

      final promptTemplate = await _loadPromptTemplate('prompt_to_line_art');
      final prompt = promptTemplate.replaceAll('{userPrompt}', userPrompt);

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

      for (int y = 0; y < image.height; y++) {
        for (int x = 0; x < image.width; x++) {
          final pixel = image.getPixel(x, y);
          final luminance = img.getLuminance(pixel);
          
          final newPixel = luminance < 128
              ? img.ColorRgb8(0, 0, 0)
              : img.ColorRgb8(255, 255, 255);
          
          image.setPixel(x, y, newPixel);
        }
      }

      // Simple dilation to thicken lines
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
}