
import 'package:mvskoke_language_app/bus/database_helper.dart';
import 'package:mvskoke_language_app/model/example.dart';
import 'package:mvskoke_language_app/model/term.dart';
import 'package:mvskoke_language_app/model/search_result.dart';
import 'package:mvskoke_language_app/screens/details.dart';
import 'package:flutter/material.dart';

class DefinitionItem extends StatelessWidget {
  final bool hasMultiple;
  final int itemIndex;
  final Term def;
  // final AudioPlayer audioPlayer = AudioPlayer();

  DefinitionItem({
    Key key,
    @required this.itemIndex,
    @required this.def,
    @required this.hasMultiple
  }) : super(key: key);

  Future<void> _searchSimilarTerm(BuildContext context, String searchTerm) async {
    var results = await DatabaseHelper.instance.querySimilarTerm(searchTerm);
    if (results.length > 0) {
      SearchResult term = results.elementAt(0);
      var router = new MaterialPageRoute(builder: (BuildContext context) {
        return Details(title: "", term: term);
      });

      Navigator.of(context).push(router);
    }
  }

  _play(String audioFile) async {
    // String url = "https://dege-dictionary-bucket.s3.amazonaws.com/audio/" + audioFile;
    // print("playing url "+url);
    // audioPlayer.stop();
    // try {
    //   audioPlayer.play(url);
    // } catch (e) {
    //   print("ERROR playing audio: "+e);
    // }
  }

  _buildExampleContainer(TextTheme textTheme, Example example) {
    return Container(
      margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 16.0),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(width: 1.0, color: Colors.black87))
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              example.soundFile!=null && example.soundFile.isNotEmpty ?
              IconButton(
                padding: EdgeInsets.fromLTRB(4, 0, 0, 0),
                  icon: Icon(Icons.volume_up),
                  onPressed: () {
                    _play('${example.soundFile}');
                  },
                ) : Container(width: 16,),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(0, 4, 0, 0),
                  child: SelectableText.rich(
                  TextSpan(
                    text: example.exampleSource,
                    style: textTheme.bodyText2
                  )
                ),
                )
              )
            ],
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.0, 0, 0, 0),
              child: SelectableText.rich(
                TextSpan(
                  text: example.exampleTarget,
                  style: textTheme.bodyText2
                )
              )
          ),
          SizedBox(
            height: 10,
          )
        ],
      ),
    );
  }

  _buildRelatedTerm(BuildContext context, String relatedTerm) {
    List<String> relatedTerms = relatedTerm.split(" ");
    relatedTerms.insert(0, "icon");

    return new Wrap(
      children: relatedTerms.map((term) =>
      term=="icon"?
        Padding(
          padding: EdgeInsets.all(4.0),
          child: Text("👉", style: TextStyle(fontSize: 18.0))) :
          InkWell(
            child: Padding(
            padding: EdgeInsets.all(4.0),
              child: Text(
              term,
              style: Theme.of(context).textTheme.bodyText2)),
              onTap: () {
                _searchSimilarTerm(context, term);
              },
          )
      ).toList()
    );
  }



  _buildSameAs(BuildContext context, String sameAs) {
    List<String> sameAsTerms = sameAs.split(" ");
    sameAsTerms.insert(0, "icon");

    return new Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
        children: sameAsTerms.map((term) =>
        term=="icon"?
        Padding(
            padding: EdgeInsets.all(4.0),
            child: Icon(
              Icons.favorite,
              color: Colors.pink,
              size: 24.0,
              semanticLabel: 'Text to announce in accessibility modes',
            )) :
        InkWell(
          child: Padding(
              padding: EdgeInsets.all(4.0),
              child: Text(
                  term,
                  style: Theme.of(context).textTheme.bodyText2)),
          onTap: () {
            _searchSimilarTerm(context, term);
          },
        )
        ).toList()
    );
  }

  @override
  Widget build(BuildContext context) {
    TextTheme textTheme = Theme.of(context).textTheme;
//    AudioPlayer.logEnabled = true;

    return InkWell(
      child: Container(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 16.0, 16.0, 16.0),
              child: IntrinsicHeight(
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Container(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              hasMultiple? Container(
                                padding: EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 4.0),
                                decoration: BoxDecoration(
                                  color: Colors.grey[400],
                                  shape: BoxShape.circle
                                ),
                                child: Text(
                                  itemIndex.toString()
                                ),
                              ) : Container(),
                              SizedBox(
                                width: hasMultiple? 12.0 : 38.0,
                              ),
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Padding(
                                      padding: EdgeInsets.fromLTRB(0, 0, 0, 4.0),
                                      child: SelectableText.rich(
                                        TextSpan(
                                          style: textTheme.bodyText2,
                                          children: [

                                            TextSpan(
                                              text: def.pos!=null && def.pos.isNotEmpty ?
                                                def.pos + "  " : "",
                                              style: TextStyle(
                                                color: Colors.cyan[800],
                                              ),
                                            ),
                                            TextSpan(
                                              text: def.definition,
                                              style: textTheme.bodyText2,
                                            ),
                                          ],
                                        )
                                      )
                                    ),
                                    for (Example ex in def.examples)
                                      _buildExampleContainer(textTheme, ex),
                                    if (def.relatedTerm!=null && def.relatedTerm.isNotEmpty)
                                      _buildRelatedTerm(context, def.relatedTerm),
                                  ],
                                ),
                              ),
                            ],
                          )
                        ),
                      )
                    ]),
              ),
            )),
    );
  }
}
