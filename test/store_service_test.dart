import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mvskoke_language_app/services/store_service.dart';

void main() {
  late Directory hiveDirectory;
  late Box settingsBox;
  late StoreService store;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('mvskoke-hive-test');
    Hive.init(hiveDirectory.path);
    settingsBox = await Hive.openBox('settings');
    store = StoreService(settingsBox);
  });

  tearDown(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('persists and restores video playback progress', () async {
    expect(store.getVideoProgress('interview'), isNull);

    await store.saveVideoProgress(
      'interview',
      position: const Duration(seconds: 45),
      duration: const Duration(seconds: 180),
    );

    final progress = store.getVideoProgress('interview');
    expect(progress?.position, const Duration(seconds: 45));
    expect(progress?.duration, const Duration(seconds: 180));
    expect(progress?.fraction, 0.25);
  });
}
