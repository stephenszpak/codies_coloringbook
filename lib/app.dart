import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/routing.dart';
import 'core/theme.dart';

class ColoringBookApp extends ConsumerWidget {
  const ColoringBookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Coloring Book',
      theme: AppTheme.light,
      routes: AppRouter.routes,
      onGenerateRoute: AppRouter.generateRoute,
      debugShowCheckedModeBanner: false,
    );
  }
}