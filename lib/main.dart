import 'dart:async';

import 'package:mvskoke_language_app/app.dart';
import 'package:mvskoke_language_app/bootstrap.dart';

Future<void> main() async {
  bootstrap(() async {
    return const MyApp();
  });
}
