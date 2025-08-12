import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/haptics.dart';
import '../../../core/result.dart';
import '../../../core/theme.dart';
import '../../../services/export_service.dart';
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
    );
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

    if (state.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coloring'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            HapticsService.lightTap();
            _saveProgress();
            Navigator.of(context).pop();
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
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'save_png',
                child: Row(
                  children: [
                    Icon(Icons.image),
                    SizedBox(width: 8),
                    Text('Export PNG'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'save_pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf),
                    SizedBox(width: 8),
                    Text('Export PDF'),
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
                onTap: _handleCanvasTap,
              ),
            ),
          ),
          ColorPalette(
            selectedColor: state.selectedColor,
            onColorChanged: (color) {
              HapticsService.selectionClick();
              ref.read(coloringProvider(widget.pageId).notifier).setSelectedColor(color);
            },
            onEraserTapped: () {
              HapticsService.selectionClick();
              ref.read(coloringProvider(widget.pageId).notifier).setEraserSelected(true);
            },
            isEraserSelected: state.isEraserSelected,
          ),
        ],
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
    final notifier = ref.read(coloringProvider(widget.pageId).notifier);

    if (state.colorLayer == null || state.outlineLayer == null || state.page == null) {
      return;
    }

    HapticsService.mediumTap();

    _performFloodFill(
      offset.dx.toInt(),
      offset.dy.toInt(),
      state.isEraserSelected 
          ? Colors.transparent 
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
      _applyUndoRedoAction(action);
    }
  }

  void _redo() {
    final state = ref.read(coloringProvider(widget.pageId));
    final notifier = ref.read(coloringProvider(widget.pageId).notifier);

    if (state.page == null) return;

    final action = notifier.popRedoAction();
    if (action != null) {
      HapticsService.mediumTap();
      _applyUndoRedoAction(action);
    }
  }

  Future<void> _applyUndoRedoAction(UndoRedoAction action) async {
    final state = ref.read(coloringProvider(widget.pageId));
    final notifier = ref.read(coloringProvider(widget.pageId).notifier);

    if (state.page == null) return;

    try {
      final currentBytes = await File(state.page!.workingImagePath).readAsBytes();
      final result = FloodFillService.applyUndoAction(currentBytes, action);

      if (result != null) {
        await File(state.page!.workingImagePath).writeAsBytes(result);
        
        final newColorLayer = await decodeImageFromList(result);
        notifier.setImages(newColorLayer, state.outlineLayer);
      }
    } catch (e) {
      notifier.setError('Failed to undo/redo: ${e.toString()}');
    }
  }

  Future<void> _saveProgress() async {
    final state = ref.read(coloringProvider(widget.pageId));
    if (state.page == null) return;

    try {
      // Progress is automatically saved after each flood fill operation
      // This method could be extended for additional cleanup or final saves
    } catch (e) {
      // Ignore save errors when leaving
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
        _exportPNG();
        break;
      case 'save_pdf':
        _exportPDF();
        break;
      case 'share':
        _shareImage();
        break;
    }
  }

  Future<void> _exportPNG() async {
    final state = ref.read(coloringProvider(widget.pageId));
    
    if (state.colorLayer == null || state.outlineLayer == null) return;

    try {
      _showLoading('Exporting PNG...');
      
      final result = await ExportService.exportToPNG(
        state.colorLayer!,
        state.outlineLayer!,
      );

      Navigator.of(context).pop(); // Close loading dialog

      result.fold(
        onSuccess: (filePath) {
          _showSuccess('PNG saved successfully!');
        },
        onFailure: (error) {
          _showError('Failed to export PNG: $error');
        },
      );
    } catch (e) {
      Navigator.of(context).pop();
      _showError('Failed to export PNG: ${e.toString()}');
    }
  }

  Future<void> _exportPDF() async {
    final state = ref.read(coloringProvider(widget.pageId));
    
    if (state.colorLayer == null || state.outlineLayer == null) return;

    try {
      _showLoading('Exporting PDF...');
      
      final result = await ExportService.exportToPDF(
        state.colorLayer!,
        state.outlineLayer!,
      );

      Navigator.of(context).pop(); // Close loading dialog

      result.fold(
        onSuccess: (filePath) {
          _showSuccess('PDF saved successfully!');
        },
        onFailure: (error) {
          _showError('Failed to export PDF: $error');
        },
      );
    } catch (e) {
      Navigator.of(context).pop();
      _showError('Failed to export PDF: ${e.toString()}');
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(message),
          ],
        ),
      ),
    );
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
}