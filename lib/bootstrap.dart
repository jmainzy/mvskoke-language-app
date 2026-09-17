import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mvskoke_language_app/services/navigation_helper.dart';
import 'package:window_size/window_size.dart';

import 'services/service_locator.dart';

Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();
  // if platform is macOS
  if (Platform.isMacOS) {
    setWindowTitle("Mvskoke Opunvkv");
  }

  usePathUrlStrategy();

  await Hive.initFlutter();
  final box = await Hive.openBox('hymnal');
  setupServiceLocator(box: box);

  NavigationHelper.instance;

  runApp(await builder());
}
