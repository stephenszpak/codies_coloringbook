import 'dart:convert';
import 'dart:ui';

class ColoringPage {
  final String id;
  final DateTime createdAt;
  final String? sourceImagePath;
  final String outlineImagePath;
  final String workingImagePath;
  final int width;
  final int height;
  final String thumbnailPath;

  const ColoringPage({
    required this.id,
    required this.createdAt,
    this.sourceImagePath,
    required this.outlineImagePath,
    required this.workingImagePath,
    required this.width,
    required this.height,
    required this.thumbnailPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'sourceImagePath': sourceImagePath,
      'outlineImagePath': outlineImagePath,
      'workingImagePath': workingImagePath,
      'width': width,
      'height': height,
      'thumbnailPath': thumbnailPath,
    };
  }

  factory ColoringPage.fromJson(Map<String, dynamic> json) {
    return ColoringPage(
      id: json['id'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      sourceImagePath: json['sourceImagePath'],
      outlineImagePath: json['outlineImagePath'],
      workingImagePath: json['workingImagePath'],
      width: json['width'],
      height: json['height'],
      thumbnailPath: json['thumbnailPath'],
    );
  }

  ColoringPage copyWith({
    String? id,
    DateTime? createdAt,
    String? sourceImagePath,
    String? outlineImagePath,
    String? workingImagePath,
    int? width,
    int? height,
    String? thumbnailPath,
  }) {
    return ColoringPage(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      sourceImagePath: sourceImagePath ?? this.sourceImagePath,
      outlineImagePath: outlineImagePath ?? this.outlineImagePath,
      workingImagePath: workingImagePath ?? this.workingImagePath,
      width: width ?? this.width,
      height: height ?? this.height,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
    );
  }
}

enum UndoActionType { floodFill, stroke }

class UndoRedoAction {
  final UndoActionType type;
  final int x;
  final int y;
  final List<int> pixels;
  final List<DrawStroke>? strokesBefore;
  final List<DrawStroke>? strokesAfter;
  
  const UndoRedoAction({
    required this.type,
    required this.x,
    required this.y,
    required this.pixels,
    this.strokesBefore,
    this.strokesAfter,
  });
}

class DrawStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  const DrawStroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });
}