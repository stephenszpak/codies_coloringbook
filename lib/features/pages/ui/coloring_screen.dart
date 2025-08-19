import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/haptics.dart';
import '../../../core/result.dart';
import '../../../core/theme.dart';
import '../../../services/export_service.dart';
import '../../../widgets/crayon_loader.dart';
import '../data/coloring_page.dart';
import '../data/pages_repository.dart';
import '../processing/flood_fill.dart';
import 'color_palette.dart';
import 'widgets/canvas_painter.dart';

class ColoringNotifier extends StateNotifier<ColoringState> {
  ColoringNotifier() : super(const ColoringState());

  void setPage(ColoringPage page) {
    state = state.copyWith(page: page);
  }

  void setImages(ui.Image? colorLayer, ui.Image? outlineLayer) {
    state = state.copyWith(
      colorLayer: colorLayer,
      outlineLayer: outlineLayer,
    );
  }

  void setSelectedColor(Color color) {
    state = state.copyWith(
      selectedColor: color,
      isEraserSelected: false,
    );
  }

  void setEraserSelected(bool selected) {
    state = state.copyWith(
      isEraserSelected: selected,
    );
  }
  /// Update the brush stroke width for freehand drawing.
  void setBrushSize(double size) {
    state = state.copyWith(brushSize: size);
  }
  /// Begin a new freehand stroke at the given image coordinate.
  void startStroke(Offset point) {
    final color = state.isEraserSelected ? Colors.white : state.selectedColor;
    final stroke = DrawStroke(
      points: [point],
      color: color,
      strokeWidth: state.brushSize,
    );
    state = state.copyWith(strokes: [...state.strokes, stroke]);
  }

  /// Continue the current freehand stroke by adding a new point.
  void updateStroke(Offset point) {
    if (state.strokes.isEmpty) return;
    final updated = List<DrawStroke>.from(state.strokes);
    final last = updated.removeLast();
    final newPoints = List<Offset>.from(last.points)..add(point);
    updated.add(DrawStroke(points: newPoints, color: last.color, strokeWidth: last.strokeWidth));
    state = state.copyWith(strokes: updated);
  }

  /// End the current freehand stroke and create undo action.
  void endStroke() {
    if (state.strokes.isNotEmpty) {
      // Create undo action for stroke
      final strokesBefore = List<DrawStroke>.from(state.strokes)..removeLast();
      final strokesAfter = List<DrawStroke>.from(state.strokes);
      
      final undoAction = UndoRedoAction(
        type: UndoActionType.stroke,
        x: 0,
        y: 0,
        pixels: [],
        strokesBefore: strokesBefore,
        strokesAfter: strokesAfter,
      );
      
      addUndoAction(undoAction);
    }
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setError(String? error) {
    state = state.copyWith(errorMessage: error);
  }

  void addUndoAction(UndoRedoAction action) {
    final newUndoStack = List<UndoRedoAction>.from(state.undoStack);
    newUndoStack.add(action);
    
    if (newUndoStack.length > 5) {
      newUndoStack.removeAt(0);
    }
    
    state = state.copyWith(
      undoStack: newUndoStack,
      redoStack: [],
      hasUnsavedChanges: true,
    );
  }

  void markPageSaved() {
    state = state.copyWith(hasUnsavedChanges: false);
  }

  void clearAllStrokes() {
    state = state.copyWith(strokes: []);
  }

  void setStrokes(List<DrawStroke> strokes) {
    state = state.copyWith(strokes: strokes);
  }

  UndoRedoAction? popUndoAction() {
    if (state.undoStack.isEmpty) return null;
    
    final action = state.undoStack.last;
    final newUndoStack = List<UndoRedoAction>.from(state.undoStack)..removeLast();
    final newRedoStack = List<UndoRedoAction>.from(state.redoStack)..add(action);
    
    state = state.copyWith(
      undoStack: newUndoStack,
      redoStack: newRedoStack,
    );
    
    return action;
  }

  UndoRedoAction? popRedoAction() {
    if (state.redoStack.isEmpty) return null;
    
    final action = state.redoStack.last;
    final newRedoStack = List<UndoRedoAction>.from(state.redoStack)..removeLast();
    final newUndoStack = List<UndoRedoAction>.from(state.undoStack)..add(action);
    
    state = state.copyWith(
      undoStack: newUndoStack,
      redoStack: newRedoStack,
    );
    
    return action;
  }
}

class ColoringState {
  final ColoringPage? page;
  final ui.Image? colorLayer;
  final ui.Image? outlineLayer;
  final Color selectedColor;
  final bool isEraserSelected;
  final List<UndoRedoAction> undoStack;
  final List<UndoRedoAction> redoStack;
  final bool isLoading;
  final String? errorMessage;
  final double brushSize;
  final List<DrawStroke> strokes;
  final bool hasUnsavedChanges;

  const ColoringState({
    this.page,
    this.colorLayer,
    this.outlineLayer,
    this.selectedColor = Colors.red,
    this.isEraserSelected = false,
    this.undoStack = const [],
    this.redoStack = const [],
    this.isLoading = false,
    this.errorMessage,
    this.brushSize = 10.0,
    this.strokes = const [],
    this.hasUnsavedChanges = false,
  });

  ColoringState copyWith({
    ColoringPage? page,
    ui.Image? colorLayer,
    ui.Image? outlineLayer,
    Color? selectedColor,
    bool? isEraserSelected,
    List<UndoRedoAction>? undoStack,
    List<UndoRedoAction>? redoStack,
    bool? isLoading,
    String? errorMessage,
    double? brushSize,
    List<DrawStroke>? strokes,
    bool? hasUnsavedChanges,
  }) {
    return ColoringState(
      page: page ?? this.page,
      colorLayer: colorLayer ?? this.colorLayer,
      outlineLayer: outlineLayer ?? this.outlineLayer,
      selectedColor: selectedColor ?? this.selectedColor,
      isEraserSelected: isEraserSelected ?? this.isEraserSelected,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      brushSize: brushSize ?? this.brushSize,
      strokes: strokes ?? this.strokes,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
    );
  }
}

final coloringProvider = StateNotifierProvider.family.autoDispose<ColoringNotifier, ColoringState, String>(
  (ref, pageId) => ColoringNotifier(),
);

class ColoringScreen extends ConsumerStatefulWidget {
  final String pageId;

  const ColoringScreen({
    super.key,
    required this.pageId,
  });

  @override
  ConsumerState<ColoringScreen> createState() => _ColoringScreenState();
}

class _ColoringScreenState extends ConsumerState<ColoringScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadColoringPage();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(coloringProvider(widget.pageId));
    final theme = Theme.of(context);
    final notifier = ref.read(coloringProvider(widget.pageId).notifier);

    if (state.isLoading) {
      return const CrayonLoadingScreen(
        message: 'Loading your coloring page...',
      );
    }

    if (state.errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Oops!',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  state.errorMessage!,
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _handleBackButton();
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Coloring'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            HapticsService.lightTap();
            _handleBackButton();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: state.undoStack.isNotEmpty ? _undo : null,
            tooltip: 'Undo',
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: state.redoStack.isNotEmpty ? _redo : null,
            tooltip: 'Redo',
          ),
          IconButton(
            icon: const Icon(Icons.clear_all, color: Colors.red),
            onPressed: _showClearAllConfirmation,
            tooltip: 'Clear All',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'save_png',
                child: Row(
                  children: [
                    Icon(Icons.save_alt),
                    SizedBox(width: 8),
                    Text('Save to Photos'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share),
                    SizedBox(width: 8),
                    Text('Share'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.white,
              child: ColoringCanvas(
                colorLayer: state.colorLayer,
                outlineLayer: state.outlineLayer,
                strokes: state.strokes,
                onTap: _handleCanvasTap,
                onPanStart: notifier.startStroke,
                onPanUpdate: notifier.updateStroke,
                onPanEnd: notifier.endStroke,
              ),
            ),
          ),
          // Brush size selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Brush size:'),
                Expanded(
                  child: Slider(
                    value: state.brushSize,
                    min: 1.0,
                    max: 20.0,
                    divisions: 19,
                    label: state.brushSize.round().toString(),
                    onChanged: (value) {
                      notifier.setBrushSize(value);
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: ColorPalette(
              selectedColor: state.selectedColor,
              onColorChanged: (color) {
                HapticsService.selectionClick();
                notifier.setSelectedColor(color);
              },
              onEraserTapped: () {
                HapticsService.selectionClick();
                notifier.setEraserSelected(true);
              },
              isEraserSelected: state.isEraserSelected,
            ),
          ),
        ],
      ),
      ),
    );
  }

  Future<void> _loadColoringPage() async {
    final notifier = ref.read(coloringProvider(widget.pageId).notifier);
    final repository = ref.read(pagesRepositoryProvider);

    notifier.setLoading(true);

    try {
      final result = await repository.getPage(widget.pageId);
      if (result.isFailure || result.dataOrNull == null) {
        notifier.setError('Coloring page not found');
        return;
      }

      final page = result.dataOrNull!;
      notifier.setPage(page);

      final colorBytes = await File(page.workingImagePath).readAsBytes();
      final outlineBytes = await File(page.outlineImagePath).readAsBytes();

      final colorLayer = await decodeImageFromList(colorBytes);
      final outlineLayer = await decodeImageFromList(outlineBytes);

      notifier.setImages(colorLayer, outlineLayer);
    } catch (e) {
      notifier.setError('Failed to load coloring page: ${e.toString()}');
    } finally {
      notifier.setLoading(false);
    }
  }

  void _handleCanvasTap(Offset offset) {
    final state = ref.read(coloringProvider(widget.pageId));

    if (state.colorLayer == null || state.outlineLayer == null || state.page == null) {
      return;
    }

    HapticsService.mediumTap();

    _performFloodFill(
      offset.dx.toInt(),
      offset.dy.toInt(),
      state.isEraserSelected 
          ? Colors.white 
          : state.selectedColor,
    );
  }

  Future<void> _performFloodFill(int x, int y, Color fillColor) async {
    final state = ref.read(coloringProvider(widget.pageId));
    final notifier = ref.read(coloringProvider(widget.pageId).notifier);

    if (state.page == null || state.colorLayer == null || state.outlineLayer == null) {
      return;
    }

    try {
      final colorBytes = await File(state.page!.workingImagePath).readAsBytes();
      final outlineBytes = await File(state.page!.outlineImagePath).readAsBytes();

      final beforeBytes = Uint8List.fromList(colorBytes);

      final result = FloodFillService.floodFill(
        colorLayerBytes: colorBytes,
        outlineBytes: outlineBytes,
        x: x,
        y: y,
        fillColor: fillColor,
        imageWidth: state.page!.width,
        imageHeight: state.page!.height,
      );

      if (result != null) {
        await File(state.page!.workingImagePath).writeAsBytes(result);
        
        final undoAction = FloodFillService.createUndoAction(
          beforeBytes: beforeBytes,
          afterBytes: result,
          x: x,
          y: y,
        );
        notifier.addUndoAction(undoAction);

        final newColorLayer = await decodeImageFromList(result);
        notifier.setImages(newColorLayer, state.outlineLayer);
      }
    } catch (e) {
      notifier.setError('Failed to fill color: ${e.toString()}');
    }
  }

  void _undo() {
    final state = ref.read(coloringProvider(widget.pageId));
    final notifier = ref.read(coloringProvider(widget.pageId).notifier);

    if (state.page == null) return;

    final action = notifier.popUndoAction();
    if (action != null) {
      HapticsService.mediumTap();
      _applyUndoRedoAction(action, isRedo: false);
    }
  }

  void _redo() {
    final state = ref.read(coloringProvider(widget.pageId));
    final notifier = ref.read(coloringProvider(widget.pageId).notifier);

    if (state.page == null) return;

    final action = notifier.popRedoAction();
    if (action != null) {
      HapticsService.mediumTap();
      _applyUndoRedoAction(action, isRedo: true);
    }
  }

  Future<void> _applyUndoRedoAction(UndoRedoAction action, {required bool isRedo}) async {
    final state = ref.read(coloringProvider(widget.pageId));
    final notifier = ref.read(coloringProvider(widget.pageId).notifier);

    if (state.page == null) return;

    try {
      switch (action.type) {
        case UndoActionType.floodFill:
          final currentBytes = await File(state.page!.workingImagePath).readAsBytes();
          final result = FloodFillService.applyUndoAction(currentBytes, action);

          if (result != null) {
            await File(state.page!.workingImagePath).writeAsBytes(result);
            
            final newColorLayer = await decodeImageFromList(result);
            notifier.setImages(newColorLayer, state.outlineLayer);
          }
          
          // Handle stroke restoration for "clear all" operations
          if (action.strokesBefore != null && action.strokesAfter != null) {
            if (isRedo) {
              // Redo: restore "after" state (empty strokes for clear all)
              notifier.setStrokes(action.strokesAfter!);
            } else {
              // Undo: restore "before" state (original strokes before clear all)
              notifier.setStrokes(action.strokesBefore!);
            }
          }
          break;
          
        case UndoActionType.stroke:
          // For stroke operations, use "after" state for redo, "before" state for undo
          if (isRedo && action.strokesAfter != null) {
            notifier.setStrokes(action.strokesAfter!);
          } else if (!isRedo && action.strokesBefore != null) {
            notifier.setStrokes(action.strokesBefore!);
          }
          break;
      }
    } catch (e) {
      notifier.setError('Failed to undo/redo: ${e.toString()}');
    }
  }

  Future<void> _handleBackButton() async {
    final state = ref.read(coloringProvider(widget.pageId));
    
    if (state.hasUnsavedChanges) {
      _showSaveDialog();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _showSaveDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save Your Coloring Page?'),
          content: const Text('You have made changes to this coloring page. Would you like to save it to My Pages?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Exit coloring screen
              },
              child: const Text('Don\'t Save'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog only - stay in coloring screen
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _saveAndExit();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveAndExit() async {
    final state = ref.read(coloringProvider(widget.pageId));
    final notifier = ref.read(coloringProvider(widget.pageId).notifier);
    
    if (state.page == null) {
      Navigator.of(context).pop();
      return;
    }

    try {
      _showLoading('Saving your page...');
      
      // Save the current state to the working image file
      await _finalizeColoringPage();
      
      // Mark as saved
      notifier.markPageSaved();
      
      Navigator.of(context).pop(); // Close loading dialog
      Navigator.of(context).pop(); // Exit coloring screen
      
      _showSuccess('Coloring page saved successfully!');
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      _showError('Failed to save: ${e.toString()}');
    }
  }

  Future<void> _finalizeColoringPage() async {
    final state = ref.read(coloringProvider(widget.pageId));
    
    if (state.page == null || state.colorLayer == null || state.outlineLayer == null) {
      return;
    }

    try {
      // If there are strokes, we need to render them into the color layer
      if (state.strokes.isNotEmpty) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        
        final colorPaint = Paint()
          ..filterQuality = FilterQuality.none
          ..isAntiAlias = false;

        final srcRect = Rect.fromLTWH(
          0,
          0,
          state.colorLayer!.width.toDouble(),
          state.colorLayer!.height.toDouble(),
        );

        // Draw the current color layer
        canvas.drawImageRect(state.colorLayer!, srcRect, srcRect, colorPaint);

        // Draw all strokes on top
        for (final stroke in state.strokes) {
          final strokePaint = Paint()
            ..color = stroke.color
            ..strokeWidth = stroke.strokeWidth
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..filterQuality = FilterQuality.none
            ..isAntiAlias = true;
          
          if (stroke.points.length < 2) {
            canvas.drawPoints(ui.PointMode.points, stroke.points, strokePaint);
          } else {
            for (var i = 1; i < stroke.points.length; i++) {
              canvas.drawLine(stroke.points[i - 1], stroke.points[i], strokePaint);
            }
          }
        }

        // Convert to image and save
        final picture = recorder.endRecording();
        final finalImage = await picture.toImage(
          state.colorLayer!.width,
          state.colorLayer!.height,
        );
        
        final pngBytes = await finalImage.toByteData(format: ui.ImageByteFormat.png);
        if (pngBytes != null) {
          await File(state.page!.workingImagePath).writeAsBytes(pngBytes.buffer.asUint8List());
        }
      }
    } catch (e) {
      throw Exception('Failed to finalize coloring page: $e');
    }
  }

  void _handleMenuAction(String action) {
    final state = ref.read(coloringProvider(widget.pageId));
    
    if (state.colorLayer == null || state.outlineLayer == null) {
      _showError('No image to export');
      return;
    }

    switch (action) {
      case 'save_png':
        _saveToPhotos();
        break;
      case 'share':
        _shareImage();
        break;
    }
  }

  Future<void> _saveToPhotos() async {
    final state = ref.read(coloringProvider(widget.pageId));
    
    if (state.colorLayer == null || state.outlineLayer == null) return;

    try {
      _showLoading('Saving to Photos...');
      
      // Let the ExportService handle all permission logic
      final result = await ExportService.saveToPhotoLibrary(
        state.colorLayer!,
        state.outlineLayer!,
        strokes: state.strokes,
      );

      // Close loading dialog first
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (!mounted) return;

      result.fold(
        onSuccess: (_) {
          _showSuccess('Saved to Photos successfully!');
        },
        onFailure: (error) {
          _showPermissionError(error);
        },
      );
    } catch (e) {
      // Ensure loading dialog is closed even on exception
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      if (mounted) {
        _showError('Failed to save to Photos: ${e.toString()}');
      }
    }
  }


  Future<void> _shareImage() async {
    final state = ref.read(coloringProvider(widget.pageId));
    
    if (state.colorLayer == null || state.outlineLayer == null) return;

    try {
      _showLoading('Preparing to share...');
      
      final exportResult = await ExportService.exportToPNG(
        state.colorLayer!,
        state.outlineLayer!,
        strokes: state.strokes,
      );

      Navigator.of(context).pop(); // Close loading dialog

      if (exportResult.isSuccess) {
        final shareResult = await ExportService.shareFile(
          exportResult.dataOrNull!,
          text: 'Check out my coloring page!',
        );

        if (shareResult.isFailure) {
          _showError('Failed to share: ${shareResult.errorMessage}');
        }
      } else {
        _showError('Failed to prepare image: ${exportResult.errorMessage}');
      }
    } catch (e) {
      Navigator.of(context).pop();
      _showError('Failed to share: ${e.toString()}');
    }
  }

  void _showLoading(String message) {
    CrayonLoadingDialog.show(context, message);
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showPermissionError(String error) {
    // Check if this is a permission-related error that needs special handling
    if (error.contains('permanently denied') || error.contains('Settings >')) {
      _showPermissionDialog(
        title: 'Photo Library Access Needed',
        message: error,
        showSettingsButton: true,
      );
    } else if (error.contains('permission') || error.contains('access')) {
      _showPermissionDialog(
        title: 'Photo Library Access',
        message: error,
        showSettingsButton: false,
      );
    } else {
      _showError('Failed to save to Photos: $error');
    }
  }

  void _showPermissionDialog({
    required String title,
    required String message,
    required bool showSettingsButton,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            if (showSettingsButton)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            if (!showSettingsButton)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  // Retry the save operation
                  _saveToPhotos();
                },
                child: const Text('Try Again'),
              ),
          ],
        );
      },
    );
  }

  Future<void> _openAppSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      _showError('Could not open settings. Please manually enable photo library access in Settings.');
    }
  }


  void _showClearAllConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear All'),
          content: const Text(
            'Are you sure you want to clear all coloring? This will remove all colors and strokes, but keep the original outline.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _clearAll();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearAll() async {
    final state = ref.read(coloringProvider(widget.pageId));
    final notifier = ref.read(coloringProvider(widget.pageId).notifier);
    
    if (state.page == null || state.outlineLayer == null) return;

    try {
      _showLoading('Clearing all coloring...');
      
      // Read current state before clearing for undo
      final beforeBytes = await File(state.page!.workingImagePath).readAsBytes();
      
      // Create empty color layer with the same dimensions as the outline
      final emptyColorBytes = FloodFillService.createEmptyColorLayer(
        state.page!.width, 
        state.page!.height,
      );
      
      // Save the empty color layer to the working image file
      await File(state.page!.workingImagePath).writeAsBytes(emptyColorBytes);
      final undoAction = UndoRedoAction(
        type: UndoActionType.floodFill,
        x: 0,
        y: 0,
        pixels: beforeBytes,
        strokesBefore: state.strokes,
        strokesAfter: const [],
      );
      
      // Update the state
      final newColorLayer = await decodeImageFromList(emptyColorBytes);
      notifier.setImages(newColorLayer, state.outlineLayer);
      
      // Clear all strokes
      notifier.clearAllStrokes();
      
      // Add undo action
      notifier.addUndoAction(undoAction);
      
      // Close loading dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      
      if (mounted) {
        _showSuccess('All coloring cleared!');
      }
      
      HapticsService.mediumTap();
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      if (mounted) {
        _showError('Failed to clear coloring: ${e.toString()}');
      }
    }
  }
}
