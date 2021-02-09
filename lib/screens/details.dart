import 'dart:ui';
import 'package:mvskoke_language_app/bus/databaseHelper.dart';
import 'package:mvskoke_language_app/model/term.dart';
import 'package:mvskoke_language_app/model/searchResult.dart';
import 'package:mvskoke_language_app/screens/home.dart';
import 'package:mvskoke_language_app/widget/definitionItem.dart';
import 'package:flutter/material.dart';

class Details extends StatefulWidget {
  final String title;
  final SearchResult term;

  Details({Key key, this.title, this.term})
      : super(key: key);

  @override
  _DetailsState createState() => _DetailsState();
}

class _DetailsState extends State<Details> {
  // AudioPlayer audioPlayer = AudioPlayer();
  
  @override
  void initState() {
    super.initState();
    _getTermForId(widget.term.id);
  }

  // _play(String audioFile) async {
  //   String url = "https://dege-dictionary-bucket.s3.amazonaws.com/audio/" + audioFile;
  //   audioPlayer.stop();
  //   audioPlayer.play(url);
  // }

  Future<List<Term>> _getTermForId(int termId) async {
    var results = await DatabaseHelper.instance.getTermForId(termId);
    return results;
  }

  _buildItems() {
    return FutureBuilder<List<Term>>(
          future: _getTermForId(widget.term.id),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return ListView.builder(
                physics: NeverScrollableScrollPhysics(), //disable bouncing
                shrinkWrap: true,
                itemCount: snapshot == null ? 0 : snapshot.data.length,
                itemBuilder: (context, index) {
                  bool hasMultiple = snapshot.data.length>1;
                  return DefinitionItem(
                      itemIndex: index + 1,
                      def: snapshot.data.elementAt(index),
                      hasMultiple: hasMultiple
                  );
                });
            } else if (snapshot.hasError) {
              return Text("${snapshot.error}");
            } else {
              return Text("");
            }
            
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0.0,
          actions: <Widget>[
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
        backgroundColor: Colors.white,
        body: SingleChildScrollView (
          child: Column (
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(16.0, 16.0, 32.0, 0.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  widget.term.soundFile != null && widget.term.soundFile.isNotEmpty ?
                    IconButton(
                      icon: Icon(Icons.volume_up),
                      alignment: Alignment.centerLeft,
                      onPressed: () {
                        // _play('${widget.term.soundFile}');
                      },
                    ) : Container(width: 10),
                    Flexible(
                    child: SelectableText.rich(
                      TextSpan(
                      children: <TextSpan>[
                        TextSpan(text: widget.term.lexeme + " ",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 24
                        )),
                        TextSpan(text: widget.term.phonetics,
                          style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          ),
                          )
                        ],
                      )
                    ))
                  ]
              ),
            ),
            _buildItems(),
          ],
        )
        )
    );
  }
}