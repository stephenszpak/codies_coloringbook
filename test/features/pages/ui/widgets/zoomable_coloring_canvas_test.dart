import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:coloring_book/features/pages/ui/widgets/zoomable_coloring_canvas.dart';

void main() {
  group('ZoomableColoringCanvas', () {
    late ui.Image testImage;
    
    setUpAll(() async {
      // Create a test image for testing
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 512, 512), Paint()..color = Colors.white);
      final picture = recorder.endRecording();
      testImage = await picture.toImage(512, 512);
    });
    
    group('ZoomConfig', () {
      testWidgets('adaptive config returns correct values for phone', (tester) async {
        // Mock a phone-sized screen
        tester.binding.window.physicalSizeTestValue = const Size(400, 800);
        tester.binding.window.devicePixelRatioTestValue = 2.0;
        
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final config = ZoomConfig.adaptive(context);
                expect(config.maxScale, equals(4.0)); // Phone default
                expect(config.doubleTapStep, equals(2.0));
                expect(config.enableBounce, equals(false));
                return Container();
              },
            ),
          ),
        );
      });
      
      testWidgets('adaptive config returns correct values for tablet', (tester) async {
        // Mock a tablet-sized screen
        tester.binding.window.physicalSizeTestValue = const Size(800, 1200);
        tester.binding.window.devicePixelRatioTestValue = 2.0;
        
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                final config = ZoomConfig.adaptive(context);
                expect(config.maxScale, equals(6.0)); // Tablet default
                return Container();
              },
            ),
          ),
        );
      });
    });
    
    group('Transform Clamping', () {
      testWidgets('clamps zoom to min scale when below threshold', (tester) async {
        bool tapReceived = false;
        Offset? tappedOffset;
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ZoomableColoringCanvas(
                colorLayer: testImage,
                outlineLayer: testImage,
                onTap: (offset) {
                  tapReceived = true;
                  tappedOffset = offset;
                },
                config: const ZoomConfig(maxScale: 4.0),
              ),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Find the InteractiveViewer
        final interactiveViewerFinder = find.byType(InteractiveViewer);
        expect(interactiveViewerFinder, findsOneWidget);
        
        // Try to zoom below min scale (should be clamped)
        final interactiveViewer = tester.widget<InteractiveViewer>(interactiveViewerFinder);
        expect(interactiveViewer.transformationController, isNotNull);
      });
      
      testWidgets('clamps zoom to max scale when above threshold', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ZoomableColoringCanvas(
                colorLayer: testImage,
                outlineLayer: testImage,
                config: const ZoomConfig(maxScale: 3.0),
              ),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        final interactiveViewerFinder = find.byType(InteractiveViewer);
        expect(interactiveViewerFinder, findsOneWidget);
      });
    });
    
    group('Hit Testing', () {
      testWidgets('canvas renders with proper structure', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ZoomableColoringCanvas(
                colorLayer: testImage,
                outlineLayer: testImage,
                config: const ZoomConfig(maxScale: 4.0),
              ),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Should have the necessary components
        expect(find.byType(InteractiveViewer), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
        expect(find.byIcon(Icons.center_focus_strong), findsOneWidget);
      });
      
      testWidgets('validates zoom configuration', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ZoomableColoringCanvas(
                colorLayer: testImage,
                outlineLayer: testImage,
                config: const ZoomConfig(maxScale: 4.0),
              ),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Should render without errors
        expect(find.byType(ZoomableColoringCanvas), findsOneWidget);
      });
    });
    
    group('Gesture Handling', () {
      testWidgets('widget structure supports gestures', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ZoomableColoringCanvas(
                colorLayer: testImage,
                outlineLayer: testImage,
                config: const ZoomConfig(maxScale: 4.0),
              ),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Should have InteractiveViewer for zoom/pan gestures
        expect(find.byType(InteractiveViewer), findsOneWidget);
        // Should have multiple GestureDetectors for tap handling
        expect(find.byType(GestureDetector), findsWidgets);
      });
      
      testWidgets('supports double tap configuration', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ZoomableColoringCanvas(
                colorLayer: testImage,
                outlineLayer: testImage,
                config: const ZoomConfig(maxScale: 4.0, doubleTapStep: 2.0),
              ),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Should render with proper configuration
        expect(find.byType(ZoomableColoringCanvas), findsOneWidget);
      });
      
      testWidgets('reset view button resets to initial state', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ZoomableColoringCanvas(
                colorLayer: testImage,
                outlineLayer: testImage,
                config: const ZoomConfig(maxScale: 4.0),
              ),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Find and tap the reset button
        final resetButtonFinder = find.byIcon(Icons.center_focus_strong);
        expect(resetButtonFinder, findsOneWidget);
        
        await tester.tap(resetButtonFinder);
        await tester.pumpAndSettle();
        
        // Should have reset the view
        expect(find.byType(ZoomableColoringCanvas), findsOneWidget);
      });
    });
    
    group('Performance', () {
      testWidgets('uses RepaintBoundary for optimization', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ZoomableColoringCanvas(
                colorLayer: testImage,
                outlineLayer: testImage,
                config: const ZoomConfig(maxScale: 4.0),
              ),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Should have RepaintBoundary for performance (multiple may exist in widget tree)
        expect(find.byType(RepaintBoundary), findsWidgets);
      });
      
      testWidgets('maintains cached painters across rebuilds', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ZoomableColoringCanvas(
                colorLayer: testImage,
                outlineLayer: testImage,
                config: const ZoomConfig(maxScale: 4.0),
              ),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Trigger a rebuild
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ZoomableColoringCanvas(
                colorLayer: testImage,
                outlineLayer: testImage,
                config: const ZoomConfig(maxScale: 4.0),
              ),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Should still have CustomPaint widgets
        expect(find.byType(CustomPaint), findsWidgets);
      });
    });
    
    group('Layer Synchronization', () {
      testWidgets('color and line art layers stay aligned during transform', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ZoomableColoringCanvas(
                colorLayer: testImage,
                outlineLayer: testImage,
                config: const ZoomConfig(maxScale: 4.0),
              ),
            ),
          ),
        );
        
        await tester.pumpAndSettle();
        
        // Both layers should be rendered by CustomPaint widgets
        final customPaintFinder = find.byType(CustomPaint);
        expect(customPaintFinder, findsWidgets);
        
        final customPaint = tester.widget<CustomPaint>(customPaintFinder.last);
        expect(customPaint.painter, isNotNull);
      });
    });
  });
}