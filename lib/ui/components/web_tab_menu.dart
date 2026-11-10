import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WebTabMenu extends StatelessWidget {
  const WebTabMenu({super.key});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();

    final router = GoRouter.of(context);
    final currentPath = router.routeInformationProvider.value.uri.path;
    final currentTab = currentPath.startsWith('/more') ? '/more' : '/content';
    final otherTabs = <({String path, String label})>[
      if (currentTab != '/content') (path: '/content', label: 'Collections'),
      if (currentTab != '/more') (path: '/more', label: 'More'),
    ];

    return PopupMenuButton<String>(
      tooltip: 'Switch tab',
      icon: const Icon(Icons.menu),
      onSelected: router.go,
      itemBuilder: (context) => [
        for (final tab in otherTabs)
          PopupMenuItem<String>(value: tab.path, child: Text(tab.label)),
      ],
    );
  }
}
