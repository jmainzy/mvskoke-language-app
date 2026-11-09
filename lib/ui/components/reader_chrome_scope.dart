import 'package:flutter/widgets.dart';

class ReaderChromeScope extends InheritedWidget {
  const ReaderChromeScope({
    super.key,
    required this.visibility,
    required this.isActive,
    required super.child,
  });

  final ValueNotifier<bool> visibility;
  final bool isActive;

  static ReaderChromeScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ReaderChromeScope>();
  }

  @override
  bool updateShouldNotify(ReaderChromeScope oldWidget) {
    return visibility != oldWidget.visibility || isActive != oldWidget.isActive;
  }
}
