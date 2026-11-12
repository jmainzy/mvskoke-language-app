import 'package:hive/hive.dart';

class StoreService {
  late Box box;
  StoreService(this.box);

  String videoProgressKey(String contentId) => 'video_progress_$contentId';

  VideoProgress? getVideoProgress(String contentId) {
    final value = box.get(videoProgressKey(contentId));
    if (value is! Map) return null;

    final positionMs = value['positionMs'];
    final durationMs = value['durationMs'];
    if (positionMs is! num || (durationMs != null && durationMs is! num)) {
      return null;
    }

    return VideoProgress(
      position: Duration(milliseconds: positionMs.round()),
      duration: durationMs is num
          ? Duration(milliseconds: durationMs.round())
          : null,
    );
  }

  Future<void> saveVideoProgress(
    String contentId, {
    required Duration position,
    required Duration? duration,
  }) {
    return box.put(videoProgressKey(contentId), {
      'positionMs': position.inMilliseconds,
      'durationMs': duration?.inMilliseconds,
    });
  }

  @override
  double get fontSize => box.get('font_size', defaultValue: 18.0);

  double get fontScale => fontSize / 18.0;

  @override
  Future<void> setFontSize(double value) {
    box.put('font_size', value);
    return Future.value();
  }
}

class VideoProgress {
  const VideoProgress({required this.position, required this.duration});

  final Duration position;
  final Duration? duration;

  double get fraction {
    final durationMs = duration?.inMilliseconds ?? 0;
    if (durationMs <= 0) return 0;
    return (position.inMilliseconds / durationMs).clamp(0.0, 1.0);
  }
}

// class TestStoreService extends StoreService {
//   /// This is a test store service that does not use Hive.
//   TestStoreService() : super();

//   @override
//   double get fontSize => 20;

//   @override
//   Future<void> setFontSize(double value) => Future.value();
// }
