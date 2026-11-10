import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:mvskoke_language_app/ui/more/about_screen.dart';
import 'package:mvskoke_language_app/ui/more/alphabet_screen.dart';
import 'package:mvskoke_language_app/ui/content/content_list.dart';
import 'package:mvskoke_language_app/ui/content/content_page.dart';
import 'package:mvskoke_language_app/ui/components/reader_chrome_scope.dart';
import 'package:mvskoke_language_app/ui/more/more_screen.dart';
import 'package:mvskoke_language_app/ui/home_screen.dart';

Logger log = Logger();

class NavigationHelper {
  static final NavigationHelper _instance = NavigationHelper._internal();

  static late final GoRouter router;

  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();

  static final GlobalKey<NavigatorState> homeTabNavigatorKey =
      GlobalKey<NavigatorState>();

  static final GlobalKey<NavigatorState> playlistTabNavigatorKey =
      GlobalKey<NavigatorState>();

  static final GlobalKey<NavigatorState> moreTabNavigatorKey =
      GlobalKey<NavigatorState>();

  BuildContext get context =>
      router.routerDelegate.navigatorKey.currentContext!;

  GoRouterDelegate get routerDelegate => router.routerDelegate;

  GoRouteInformationParser get routeInformationParser =>
      router.routeInformationParser;

  static const String homePath = '/';
  static const String contentPath = '/content';
  static const String aboutPath = 'about';
  static const String morePath = '/more';
  static const String glossaryPath = 'glossary';
  static const String alphabetPath = 'appendix';
  static const String prayerPath = 'prayer';

  static NavigationHelper get instance => _instance;
  factory NavigationHelper() {
    return _instance;
  }

  NavigationHelper._internal() {
    final routes = [
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: rootNavigatorKey,
        branches: [
          // StatefulShellBranch(
          //   navigatorKey: homeTabNavigatorKey,
          //   routes: [
          //     GoRoute(
          //       path: homePath,
          //       pageBuilder: (context, state) {
          //         return MaterialPage(
          //           key: state.pageKey,
          //           child: const HomeScreen(),
          //         );
          //       },
          //     ),
          //   ],
          // ),
          StatefulShellBranch(
            navigatorKey: playlistTabNavigatorKey,
            routes: [
              GoRoute(
                path: contentPath,
                pageBuilder: (context, state) {
                  return MaterialPage(
                    key: state.pageKey,
                    child: const SearchWrapper(),
                  );
                },
                routes: [
                  GoRoute(
                    path: '/:contentId',
                    parentNavigatorKey: rootNavigatorKey,
                    pageBuilder: (context, state) {
                      final id = state.pathParameters['contentId'];
                      if (id == null) {
                        throw Exception('Invalid entity id');
                      } else {
                        log.i('navvy content id: $id');
                      }
                      return MaterialPage(
                        key: state.pageKey,
                        child: ContentPage(contentId: id),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: moreTabNavigatorKey,
            routes: [
              GoRoute(
                path: morePath,
                pageBuilder: (context, state) {
                  return MaterialPage(
                    child: const MoreScreen(),
                    key: state.pageKey,
                  );
                },
                routes: [
                  GoRoute(
                    path: aboutPath,
                    pageBuilder: (context, state) {
                      return MaterialPage(
                        child: const AboutScreen(),
                        key: state.pageKey,
                      );
                    },
                  ),
                  GoRoute(
                    path: alphabetPath,
                    pageBuilder: (context, state) {
                      return MaterialPage(
                        child: AlphabetScreen(),
                        key: state.pageKey,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
        pageBuilder: (context, state, navigationShell) {
          return MaterialPage(
            child: NavigationPage(child: navigationShell),
            key: state.pageKey,
          );
        },
      ),
    ];

    router = GoRouter(
      debugLogDiagnostics: true,
      initialLocation: contentPath,
      navigatorKey: rootNavigatorKey,
      errorPageBuilder: (context, state) {
        return MaterialPage(
          key: state.pageKey,
          child: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(state.error.toString()),
                  TextButton(
                    onPressed: () => context.go(contentPath),
                    child: const Text('Go to Home page'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      routes: routes,
    );
  }
}

class NavigationPage extends StatefulWidget {
  const NavigationPage({super.key, required this.child});

  final StatefulNavigationShell child;

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  final ValueNotifier<bool> _readerChromeVisibility = ValueNotifier(true);
  bool? _wasLandscape;
  bool? _wasReaderRoute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncReaderChromeVisibility();
  }

  @override
  void didUpdateWidget(covariant NavigationPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncReaderChromeVisibility();
  }

  void _syncReaderChromeVisibility() {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final currentPath =
        NavigationHelper.router.routeInformationProvider.value.uri.path;
    final isReaderRoute = currentPath.startsWith(
      '${NavigationHelper.contentPath}/',
    );
    print(
      'syncReaderChromeVisibility: isLandscape=$isLandscape, isReaderRoute=$isReaderRoute, wasLandscape=$_wasLandscape, wasReaderRoute=$_wasReaderRoute',
    );
    if (_wasLandscape == isLandscape && _wasReaderRoute == isReaderRoute) {
      return;
    }

    _wasLandscape = isLandscape;
    _wasReaderRoute = isReaderRoute;
    _readerChromeVisibility.value = !(isLandscape && isReaderRoute);
  }

  @override
  void dispose() {
    _readerChromeVisibility.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: kIsWeb
          ? null
          : ValueListenableBuilder<bool>(
              valueListenable: _readerChromeVisibility,
              builder: (context, visible, _) => visible
                  ? NavigationBar(
                      onDestinationSelected: (int index) {
                        _readerChromeVisibility.value = true;
                        widget.child.goBranch(
                          index,
                          initialLocation: index == widget.child.currentIndex,
                        );
                        setState(() {});
                      },
                      labelBehavior:
                          NavigationDestinationLabelBehavior.alwaysHide,
                      selectedIndex: widget.child.currentIndex,
                      destinations: const <Widget>[
                        NavigationDestination(
                          icon: Icon(Icons.list),
                          label: 'Collections',
                        ),
                        NavigationDestination(
                          icon: Icon(Icons.more_horiz),
                          label: 'About',
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
      body: ReaderChromeScope(
        visibility: _readerChromeVisibility,
        isActive: widget.child.currentIndex == 1,
        child: widget.child,
      ),
    );
  }
}
