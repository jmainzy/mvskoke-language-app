import 'dart:js_interop';

import 'package:web/web.dart' as web;

Stream<double> vimeoDurationStream() => web.window.onMessage
    .map((event) => event.data)
    .where((data) => data is JSAny)
    .map((data) => (data as JSAny).dartify())
    .where(
      (data) =>
          data is Map && data['readAlongVimeoDuration'] is num,
    )
    .map((data) => (data as Map)['readAlongVimeoDuration'] as num)
    .map((seconds) => seconds.toDouble());
