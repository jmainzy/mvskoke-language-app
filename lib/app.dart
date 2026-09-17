import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:mvskoke_language_app/services/navigation_helper.dart';
import 'package:mvskoke_language_app/services/service_locator.dart';
import 'package:mvskoke_language_app/services/store_service.dart';

Logger log = Logger();

class MyApp extends StatefulWidget {
  /// Indicates if the app is running in `device_preview` mode
  final bool isPreviewMode;

  const MyApp({super.key, this.isPreviewMode = false});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Mvskoke Hymnal',
      theme: ThemeData(
        useMaterial3: true,

        // Define the default brightness and colors.
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(100, 25, 175, 65),
          brightness: Brightness.light,
        ),
        textTheme: getTheme(sl<StoreService>().fontScale),
      ),
      debugShowCheckedModeBanner: false,
      routerConfig: NavigationHelper.router,
    );
  }

  TextTheme getTheme(double scale) {
    return Typography.blackHelsinki.copyWith(
      bodyLarge: Typography.blackHelsinki.bodyLarge!.copyWith(
        fontSize: 18.0 * scale,
      ),
      bodyMedium: Typography.blackHelsinki.bodyMedium!.copyWith(
        fontSize: 16.0 * scale,
      ),
      bodySmall: Typography.blackHelsinki.bodySmall!.copyWith(
        fontSize: 14.0 * scale,
      ),
      titleLarge: Typography.blackHelsinki.titleLarge!.copyWith(
        fontSize: 22.0 * scale,
      ),
      titleMedium: Typography.blackHelsinki.titleMedium!.copyWith(
        fontSize: 20.0 * scale,
      ),
      titleSmall: Typography.blackHelsinki.titleSmall!.copyWith(
        fontSize: 18.0 * scale,
      ),
    );
  }
}
