import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/result.dart';
import 'coloring_page.dart';

class PagesRepository {
  static const String _pagesKey = 'coloring_pages';
  
  Future<Result<List<ColoringPage>>> getPages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pagesJson = prefs.getString(_pagesKey);
      
      if (pagesJson == null) {
        return const Success([]);
      }
      
      final List<dynamic> pagesList = json.decode(pagesJson);
      final pages = pagesList
          .map((json) => ColoringPage.fromJson(json))
          .toList();
      
      pages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return Success(pages);
    } catch (e) {
      return Failure('Failed to load pages: ${e.toString()}');
    }
  }
  
  Future<Result<void>> savePage(ColoringPage page) async {
    try {
      final result = await getPages();
      if (result.isFailure) {
        return Failure('Failed to load existing pages: ${result.errorMessage}');
      }
      
      final pages = List<ColoringPage>.from(result.dataOrNull!);
      final existingIndex = pages.indexWhere((p) => p.id == page.id);
      
      if (existingIndex >= 0) {
        pages[existingIndex] = page;
      } else {
        pages.add(page);
      }
      
      final prefs = await SharedPreferences.getInstance();
      final pagesJson = json.encode(pages.map((p) => p.toJson()).toList());
      await prefs.setString(_pagesKey, pagesJson);
      
      return const Success(null);
    } catch (e) {
      return Failure('Failed to save page: ${e.toString()}');
    }
  }
  
  Future<Result<void>> deletePage(String pageId) async {
    try {
      final result = await getPages();
      if (result.isFailure) {
        return Failure('Failed to load existing pages: ${result.errorMessage}');
      }
      
      final pages = List<ColoringPage>.from(result.dataOrNull!);
      final pageToDelete = pages.where((p) => p.id == pageId).firstOrNull;
      
      if (pageToDelete != null) {
        await _deletePageFiles(pageToDelete);
        pages.removeWhere((p) => p.id == pageId);
        
        final prefs = await SharedPreferences.getInstance();
        final pagesJson = json.encode(pages.map((p) => p.toJson()).toList());
        await prefs.setString(_pagesKey, pagesJson);
      }
      
      return const Success(null);
    } catch (e) {
      return Failure('Failed to delete page: ${e.toString()}');
    }
  }
  
  Future<Result<ColoringPage?>> getPage(String pageId) async {
    try {
      final result = await getPages();
      if (result.isFailure) {
        return Failure('Failed to load pages: ${result.errorMessage}');
      }
      
      final pages = result.dataOrNull!;
      final page = pages.where((p) => p.id == pageId).firstOrNull;
      
      return Success(page);
    } catch (e) {
      return Failure('Failed to get page: ${e.toString()}');
    }
  }
  
  Future<void> _deletePageFiles(ColoringPage page) async {
    try {
      final files = [
        page.sourceImagePath,
        page.outlineImagePath,
        page.workingImagePath,
        page.thumbnailPath,
      ];
      
      for (final filePath in files) {
        if (filePath != null) {
          final file = File(filePath);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      // Log error but don't fail the deletion operation
    }
  }
  
  Future<String> getAppDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final coloringDir = Directory('${directory.path}/coloring_pages');
    if (!await coloringDir.exists()) {
      await coloringDir.create(recursive: true);
    }
    return coloringDir.path;
  }
}

final pagesRepositoryProvider = Provider<PagesRepository>((ref) {
  return PagesRepository();
});

final pagesProvider = FutureProvider<List<ColoringPage>>((ref) async {
  final repository = ref.watch(pagesRepositoryProvider);
  final result = await repository.getPages();
  return result.fold(
    onSuccess: (pages) => pages,
    onFailure: (error) => throw Exception(error),
  );
});