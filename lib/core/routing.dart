import 'package:flutter/material.dart';
import '../features/home/home_screen.dart';
import '../features/help/help_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/pages/ui/create_page_screen.dart';
import '../features/pages/ui/prompt_to_page_screen.dart';
import '../features/pages/ui/coloring_screen.dart';
import '../features/pages/ui/my_pages_screen.dart';

class AppRouter {
  static final Map<String, WidgetBuilder> routes = {
    '/': (context) => const HomeScreen(),
    '/help': (context) => const HelpScreen(),
    '/settings': (context) => const SettingsScreen(),
    '/create-page': (context) => const CreatePageScreen(),
    '/prompt-to-page': (context) => const PromptToPageScreen(),
    '/my-pages': (context) => const MyPagesScreen(),
  };

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/coloring':
        final pageId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (context) => ColoringScreen(pageId: pageId),
        );
      default:
        final builder = routes[settings.name];
        if (builder != null) {
          return MaterialPageRoute(builder: builder);
        }
        return MaterialPageRoute(
          builder: (context) => const Scaffold(
            body: Center(child: Text('Page not found')),
          ),
        );
    }
  }
}