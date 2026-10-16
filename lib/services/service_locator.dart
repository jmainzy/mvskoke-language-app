import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:logger/logger.dart';
import 'package:mvskoke_language_app/managers/audio_manager.dart';
import 'package:mvskoke_language_app/services/audio_player_service.dart';
import 'package:mvskoke_language_app/services/content_service.dart';
import 'package:mvskoke_language_app/services/store_service.dart';

final sl = GetIt.instance;

Logger log = Logger();

Future<void> setupServiceLocator({required Box box}) async {
  // services
  sl.registerSingleton<StoreService>(StoreService(box));
  sl.registerSingletonAsync<AudioPlayerService>(
    () => AudioPlayerService().init(),
  );
  sl.registerSingleton<ContentService>(ContentService());

  // managers
  sl.registerSingletonAsync<AudioManager>(
    () => AudioManager().init(),
    dependsOn: [AudioPlayerService],
  );
}
