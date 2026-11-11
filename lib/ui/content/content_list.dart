import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:mvskoke_language_app/models/content_item.dart';
import 'package:mvskoke_language_app/services/content_service.dart';
import 'package:mvskoke_language_app/services/navigation_helper.dart';
import 'package:mvskoke_language_app/utilities/dimens.dart';
import 'package:mvskoke_language_app/ui/components/web_tab_menu.dart';
import 'package:watch_it/watch_it.dart';

Logger log = Logger();

class SearchWrapper extends StatefulWidget {
  const SearchWrapper({super.key});

  @override
  SearchWrapperState createState() => SearchWrapperState();
}

class SearchWrapperState extends State<SearchWrapper>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  late Future<void> _loadingFuture;
  final contentService = sl<ContentService>();
  var stories = <ContentItem>[];

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    super.initState();
    _loadingFuture = _init();
    fetch();
  }

  Future<void> _init() async {
    await sl.allReady();
    if (!mounted) return;
  }

  Future<void> fetch() async {
    stories = contentService.getStories();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      appBar: AppBar(
        title: const Text('Mvskoke Opunvkv'),
        actions: const [WebTabMenu()],
        // actions: [
        //   kDebugMode
        //       ? IconButton(
        //           icon: const Icon(Icons.refresh),
        //           onPressed: () {
        //             setState(() {});
        //             _loadingFuture = fetch();
        //           },
        //         )
        //       : Container(),
        //   kDebugMode
        //       ? IconButton(onPressed: () {}, icon: const Icon(Icons.save))
        //       : Container(),
        // ],
      ),
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: FutureBuilder(
        future: _loadingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            log.e('Error loading content: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Error loading content',
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
            return ContentList(stories: stories);
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

class ContentList extends WatchingStatefulWidget {
  final List<ContentItem> stories;
  const ContentList({super.key, required this.stories});

  @override
  ContentListState createState() => ContentListState();
}

class ContentListState extends State<ContentList> {
  ContentListState();

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
              padding: const EdgeInsets.symmetric(
                horizontal: Dimens.marginLarge,
              ),
              child: Column(
                children: [
                  SearchBar(
                    controller: controller,
                    padding: const WidgetStatePropertyAll<EdgeInsets>(
                      EdgeInsets.symmetric(horizontal: 16.0),
                    ),
                    elevation: const WidgetStatePropertyAll<double>(0.0),
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
                      Theme.of(context).colorScheme.surfaceContainerLow,
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
                  // ListTile(
                  //   title: Text('suggestion'),
                  //   onTap: () {
                  //     controller.text = 'suggestion';
                  //     search('suggestion');
                  //     controller.closeView('suggestion');
                  //   },
                  // ),
                ];
              },
        ),
        Expanded(
          child: ListView.separated(
            scrollDirection: Axis.vertical,
            itemCount: widget.stories.length,
            padding: const EdgeInsets.symmetric(vertical: Dimens.marginShort),
            separatorBuilder: (BuildContext context, int index) {
              return SizedBox(height: 2);
            },
            itemBuilder: (BuildContext context, int index) {
              final story = widget.stories[index];
              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: Dimens.marginLarge,
                  vertical: Dimens.marginShort / 4,
                ),
                clipBehavior: Clip.antiAlias,
                elevation: 0,
                child: InkWell(
                  onTap: () {
                    NavigationHelper.router.push(
                      '${NavigationHelper.contentPath}/${story.id}',
                    );
                  },
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 72,
                          child: story.thumbnail == null
                              ? const Icon(Icons.book)
                              : Image.asset(
                                  'assets/images/${story.thumbnail}',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.image),
                                ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Dimens.marginLarge,
                              vertical: Dimens.marginLarge,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(story.title),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
