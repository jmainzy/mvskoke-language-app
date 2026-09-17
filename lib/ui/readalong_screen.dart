import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:mvskoke_language_app/utilities/dimens.dart';
import 'package:watch_it/watch_it.dart';

Logger log = Logger();

class ReadalongScreen extends StatefulWidget {
  const ReadalongScreen({super.key});

  @override
  ReadalongScreenState createState() => ReadalongScreenState();
}

class ReadalongScreenState extends State<ReadalongScreen> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  late Future<void> _loadingFuture;

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
    _loadingFuture = _init();
  }

  Future<void> _init() async {
    await sl.allReady();
    // await sl<ConfigService>().initConfig();
    // await sl<SongManager>().init();
    if (!mounted) return;
  }

  Future<void> fetch() async {
    // get songs again
    // final songManager = sl<SongManager>();
    // await songManager.init();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: const Text('Mvskoke Opunvkv'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          kDebugMode
              ? IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    setState(() {});
                    _loadingFuture = fetch();
                  },
                )
              : Container(),
          kDebugMode
              ? IconButton(onPressed: () {}, icon: const Icon(Icons.save))
              : Container(),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: FutureBuilder(
        future: _loadingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            log.e('Error loading songs: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Error loading songs',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      _init();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          } else {
            return const HomeContent();
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

class HomeContent extends WatchingStatefulWidget {
  const HomeContent({super.key});

  @override
  HomeContentState createState() => HomeContentState();
}

class HomeContentState extends State<HomeContent> {
  HomeContentState();

  final SearchController controller = SearchController();
  var isSearching = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  void search(String searchString) {
    // songManager.filterSongs(searchString);
    setState(() {
      isSearching = searchString.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SearchAnchor(
          searchController: controller,
          builder: (BuildContext context, SearchController controller) {
            return Padding(
              padding: const EdgeInsets.all(Dimens.marginShort),
              child: Column(
                children: [
                  SearchBar(
                    controller: controller,
                    padding: const WidgetStatePropertyAll<EdgeInsets>(
                      EdgeInsets.symmetric(horizontal: 16.0),
                    ),
                    onTap: () {
                      controller.openView();
                    },
                    onChanged: (_) {
                      controller.openView();
                    },
                    leading: const Icon(Icons.search),
                    trailing: controller.text.isNotEmpty
                        ? [
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                controller.text = '';
                                search('');
                              },
                            ),
                          ]
                        : [],
                    backgroundColor: WidgetStateProperty.all(
                      Theme.of(context).colorScheme.surface,
                    ),
                  ),
                ],
              ),
            );
          },
          viewPadding: const EdgeInsets.all(Dimens.marginShort),
          viewBarPadding: const EdgeInsets.all(Dimens.marginShort),
          viewBackgroundColor: Theme.of(context).colorScheme.surface,
          viewOnSubmitted: (value) {
            search(value);
            controller.closeView(value);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              FocusScope.of(context).unfocus();
            });
          },
          suggestionsBuilder:
              (BuildContext context, SearchController controller) {
                return [
                  ListTile(
                    title: Text('suggestion'),
                    onTap: () {
                      controller.text = 'suggestion';
                      search('suggestion');
                      controller.closeView('suggestion');
                    },
                  ),
                ];
              },
        ),
        Flexible(
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Readalongs',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
