import 'dart:collection';

import 'package:mvskoke_language_app/bus/database_helper.dart';
import 'package:mvskoke_language_app/model/search_result.dart';
import 'package:flutter/material.dart';
import 'package:mvskoke_language_app/screens/details.dart';

class ListItem extends StatelessWidget {
  final SearchResult term;
  final String searchTerm;

  ListItem({
    Key key,
    @required this.term,
    this.searchTerm
  }) : super(key: key);

  _addToSearchHistory() async {
    await DatabaseHelper.instance.insertSearchHistory(term.id);
  }

  @override
  Widget build(BuildContext context) {
//    TextTheme textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: () {
        var router = new MaterialPageRoute(builder: (BuildContext context) {
          _addToSearchHistory();
        
          return Details(title: "", term: term,);
        });

        Navigator.of(context).push(router);
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
            child: Container(
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: Container(
                        // color: Colors.indigo,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _buildSpannedTerm(context,
                                term.lexeme,
                                searchTerm,
                                Theme.of(context).textTheme.headline6
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: term.getResultLines().map((line) =>
                                Padding(
                                  padding: EdgeInsets.fromLTRB(0, 4, 0, 0),
                                  child: _buildSpannedTerm(
                                      context,
                                      line,
                                      searchTerm,
                                      Theme.of(context).textTheme.bodyText2
                                  )
                                )
                              ).toList()
                            ),
                          ],
                        ),
                      ),
                    )
                  ]
                ),
            ),
          ),
      ),
    );
  }

  Widget _buildSpannedTerm(BuildContext context, String text, String query, TextStyle textStyle) {
    List<TextSpan> spans = [];
    int start = 0;
    int indexOfHighlight;

    do {
      indexOfHighlight = text.toLowerCase().indexOf(query.toLowerCase(), start);
      if (indexOfHighlight < 0 || query.length == 0) {
        // no highlight
        spans.add(_normalSpan(text.substring(start, text.length), textStyle));
        break;
      }

      // get span from original text to include correct upper/lower case
      final highlightStr = text.substring(indexOfHighlight, indexOfHighlight + query.length);

      if (indexOfHighlight == start) {
        // start with highlight.
        spans.add(_highlightSpan(highlightStr, textStyle));
        start += query.length;
      } else {
        // normal + highlight
        spans.add(_normalSpan(text.substring(start, indexOfHighlight), textStyle));
        spans.add(_highlightSpan(highlightStr, textStyle));
        start = indexOfHighlight + query.length;
      }
    } while (true);

    return Text.rich(
      TextSpan(
          children: spans,
          style: Theme.of(context).textTheme.bodyText2
      ),
    );
  }

  TextSpan _highlightSpan(String content, TextStyle textStyle) {
    return TextSpan(text: content, style: textStyle.copyWith(color: Colors.red, fontWeight: FontWeight.bold));
  }

  TextSpan _normalSpan(String content, TextStyle textStyle) {
    return TextSpan(text: content, style: textStyle);
  }
}
