import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:image/image.dart' as img;
import '../core/result.dart';

class OpenAIBackend {
  static const String _baseUrl = 'https://api.openai.com/v1';
  final Dio _dio = Dio();

  Future<Result<Uint8List>> photoToLineArt(
    Uint8List imageBytes, 
    int outlineStrength, 
    String apiKey,
  ) async {
    try {
      final promptTemplate = await _loadPromptTemplate('photo_to_line_art');
      final prompt = promptTemplate.replaceAll('{outlineStrength}', outlineStrength.toString());

      final formData = FormData.fromMap({
        'model': 'dall-e-3',
        'prompt': prompt,
        'image': MultipartFile.fromBytes(
          imageBytes,
          filename: 'image.png',
          contentType: DioMediaType('image', 'png'),
        ),
        'size': '1024x1024',
        'response_format': 'b64_json',
      });

      final response = await _dio.post(
        '$_baseUrl/images/edits',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'multipart/form-data',
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
    String apiKey,
  ) async {
    try {
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

  Future<Result<void>> healthCheck(String apiKey) async {
    try {
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
            return 'Convert this photo into a clean black-and-white coloring-book page for a 4-year-old. Strong, continuous outlines, no shading, no gray fills, pure white background. Close all regions so tap-to-fill won\'t leak. Emphasize recognizable shapes; simplify noisy textures. Line thickness: {outlineStrength}/100 (thin→thick).';
          case 'prompt_to_line_art':
            return 'Create a kid-safe coloring-book page of: {userPrompt}. Black outlines only, no color, no shading, pure white background, medium-thick continuous lines, closed regions suitable for toddlers to color. Keep composition centered (5–8 main shapes).';
          default:
            return 'Create a simple coloring book page.';
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