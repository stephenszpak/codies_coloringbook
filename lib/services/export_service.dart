import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import '../core/result.dart';
import 'storage_service.dart';

class ExportService {
  static Future<Result<String>> exportToPNG(
    ui.Image colorLayer,
    ui.Image outlineLayer,
  ) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      final paint = Paint();
      
      final rect = Rect.fromLTWH(0, 0, 
          outlineLayer.width.toDouble(), 
          outlineLayer.height.toDouble());
      
      canvas.drawImageRect(colorLayer, rect, rect, paint);
      canvas.drawImageRect(outlineLayer, rect, rect, paint);
      
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

  static Future<Result<String>> exportToPDF(
    ui.Image colorLayer,
    ui.Image outlineLayer,
  ) async {
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      final paint = Paint();
      
      final rect = Rect.fromLTWH(0, 0, 
          outlineLayer.width.toDouble(), 
          outlineLayer.height.toDouble());
      
      canvas.drawImageRect(colorLayer, rect, rect, paint);
      canvas.drawImageRect(outlineLayer, rect, rect, paint);
      
      final picture = recorder.endRecording();
      final image = await picture.toImage(
          outlineLayer.width, 
          outlineLayer.height);
      
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();
      
      final imgImage = img.decodeImage(pngBytes);
      if (imgImage == null) {
        return const Failure('Failed to process image for PDF');
      }
      
      final pdf = pw.Document();
      final imageWidget = pw.MemoryImage(pngBytes);
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(
                imageWidget,
                fit: pw.BoxFit.contain,
              ),
            );
          },
        ),
      );
      
      final pdfBytes = await pdf.save();
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'coloring_page_$timestamp.pdf';
      
      final filePath = await StorageService.saveFile(
        filename, 
        pdfBytes,
        subfolder: 'exports',
      );
      
      return Success(filePath);
    } catch (e) {
      return Failure('Failed to export PDF: ${e.toString()}');
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
}