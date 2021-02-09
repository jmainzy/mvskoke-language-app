import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mvskoke_language_app/bus/databaseHelper.dart';
import 'package:mvskoke_language_app/model/searchResult.dart';
import 'package:mvskoke_language_app/widget/listItem.dart';
import 'package:mvskoke_language_app/widget/search-bar/app_bar_controller.dart';
import 'package:mvskoke_language_app/widget/search-bar/simple_search_bar.dart';

class Home extends StatefulWidget {
  Home({Key key}) : super(key: key);

  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final _termsController = StreamController<List<SearchResult>>.broadcast();

  // Input stream. We add our terms to the stream using this variable.
  StreamSink<List<SearchResult>> get _inTerms => _termsController.sink;

  String _searchTerm = '';
  bool _isSearchMode;

  Stream<List<SearchResult>> get terms => _termsController.stream;

  // reference to our single class that manages the database
  final dbHelper = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _getHistory();
  }

  Future<void> _getTerms(String searchTerm) async {
    var results = await DatabaseHelper.instance.querySearch(searchTerm);
    /*for (SearchResult term in results) {
      print("getTerms: ${term.lexeme}");
    }*/

    setState(() {
      _inTerms.add(results);
    });
  }

  Future<void> _getHistory() async {
    var results = await DatabaseHelper.instance.querySearchHistory();
    /*for (SearchResult term in results) {
      print("getHistory: ${term.lexeme}");
    }*/

    setState(() {
      _inTerms.add(results);
    });
  }

  _searchResults(List<SearchResult> terms) {
    return ListView.builder(
      key: ObjectKey(terms[0]),
      shrinkWrap: true,
      itemCount: terms.length,
      padding: EdgeInsets.symmetric(vertical: 14.0),
      itemBuilder: (BuildContext context, int index) {
        SearchResult term = terms[index];
        //print("_searchResults LIST ITEM: ${term.lexeme}");
        return Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 2.0, 16.0, 2.0),
          child: ListItem(
              term: term,
              searchTerm: _searchTerm
          ),
        );
      },
    );
  }

  _welcomeView() {
    return Padding(padding: EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget> [
              Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Welcome', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.grey),)
              ),
              Text('To look up a term, press the search icon in the top right corner.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center, ),
            ]
        )
    );
  }

  _noTermsView() {
    return Padding(padding: EdgeInsets.all(16),
        child: Center(
          child: const Text('No matching term found.', style: TextStyle(color: Colors.grey),),
        )
    );
  }

  _loadingView() {
    return Center(
        child: CircularProgressIndicator()
    );
  }

  _errorView(String error) {
    return Center(
      child: Text('Error: $error', style: TextStyle(color: Colors.grey),),
    );
  }

  _buildItems() {
    return StreamBuilder<List<SearchResult>>(
      stream: terms,
      builder: (BuildContext context, AsyncSnapshot<List<SearchResult>> snapshot) {
        if (snapshot.hasError) {
          return _errorView(snapshot.error);
        }
        switch (snapshot.connectionState) {
          case ConnectionState.waiting:
            return _loadingView();
          default:
            if (snapshot.data.isEmpty) {
              if (_searchTerm.isEmpty) {
                return  _welcomeView();
              } else {
                return  _noTermsView();
              }
            } else {
              return _searchResults(snapshot.data);
              //return Container();
            }
        }
      },
    );
  }

  final AppBarController appBarController = AppBarController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SearchAppBar(
        primary: Theme.of(context).primaryColor,
        appBarController: appBarController,
        // You could load the bar with search already active
        autoSelected: false,
        searchHint: "Search",
        mainTextColor: Colors.black,
        onChange: (String value) {
          //Your function to filter list. It should interact with
          //the Stream that generate the final list
          setState(() {
            _searchTerm = value;
          });
          _getTerms(value);
        },
        onTap: () {
          _getHistory();
          setState(() {
            _searchTerm = '';
            _isSearchMode = false;
          });
        },
        //Will show when SEARCH MODE wasn't active
        mainAppBar: AppBar(
          title: Text(
              "Mvskoke Language"
          ),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.search),
              onPressed:() {
                //This is where You change to SEARCH MODE. To hide, just
                //add FALSE as value on the stream
                appBarController.stream.add(true);
                setState(() {
                  _isSearchMode = true;
                });
              } ,
            ),
            // overflow menu
            PopupMenuButton<Choice>(
              icon: Icon(Icons.more_vert),
              onSelected: (Choice choice) => {
                Navigator.of(context).pushNamed(choice.route)
              },
              itemBuilder: (BuildContext context) {
                return choices.map((Choice choice) {
                  return PopupMenuItem<Choice>(
                    value: choice,
                    child: Text(choice.title),
                  );
                }).toList();
              },
            ),
          ],
        ),
      ),
      backgroundColor: Colors.blueGrey[50],
      body: _buildItems(),
    );
  }

}

class Choice {
  const Choice({this.title, this.route});

  final String title;
  final String route;
}

const List<Choice> choices = const <Choice>[
  const Choice(title: 'Overview', route: '/overview'),
  const Choice(title: 'Reference', route: '/reference'),
  const Choice(title: 'About', route: '/about'),
];

class ChoiceCard extends StatelessWidget {
  const ChoiceCard({Key key, this.choice}) : super(key: key);

  final Choice choice;

  @override
  Widget build(BuildContext context) {
    final TextStyle textStyle = Theme.of(context).textTheme.display1;
    return Card(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(choice.title, style: textStyle),
          ],
        ),
      ),
    );
  }
}