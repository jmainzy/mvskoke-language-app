import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:mvskoke_language_app/models/media_item.dart';
import 'package:mvskoke_language_app/ui/mini_audio.dart';
import 'package:mvskoke_language_app/utilities/dimens.dart';
import 'package:url_launcher/url_launcher.dart';

/// Displays a formatted block of text
class AlphabetScreen extends StatefulWidget {
  const AlphabetScreen({super.key});

  @override
  State<AlphabetScreen> createState() => _AlphabetScreenState();
}

class _AlphabetScreenState extends State<AlphabetScreen> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mvskoke Alphabet'),
      ),
      body: SingleChildScrollView(
          child: Padding(
              padding: const EdgeInsets.all(Dimens.marginLarge),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text('Mvskoke\nLetter',
                              style: Theme.of(context).textTheme.bodyLarge)),
                      Expanded(
                          child: Text('English\nExample',
                              style: Theme.of(context).textTheme.bodyLarge)),
                      Expanded(
                          child: Text('Mvskoke\nExample',
                              style: Theme.of(context).textTheme.bodyLarge)),
                    ]),
                    GptMarkdown(
                      alphabet,
                      tableBuilder: (context, tableRows, textStyle, config) {
                        return Table(
                          children: tableRows.map((e) {
                            return TableRow(
                              children: e.fields.map((e) {
                                return Text(e.data,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium);
                              }).toList(),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    Row(children: [
                      SizedBox(
                        width: Dimens.marginShort,
                      ),
                      Expanded(
                          child: Text(
                              '\nAlphabet reading by Linda Sulpher Bear:')),
                    ]),
                    MiniAudioWidget(
                        mediaItem: MediaObject(
                            id: '1',
                            title: 'Mvskoke Alphabet',
                            filename: 'alphabet.mp3',
                            performer: '',
                            copyright: '',
                            lastUpdate: null)),
                    GptMarkdown(
                      copyright,
                      linkBuilder: (context, text, url, style) => RichText(
                        text: TextSpan(
                            text: text.toPlainText(),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.blue)),
                      ),
                      onLinkTap: (url, title) {
                        launchUrl(Uri.parse(url));
                      },
                    ),
                    SizedBox(
                      height: Dimens.marginLarge,
                    ),
                    GptMarkdown(
                      dipthongs,
                      tableBuilder: (context, tableRows, textStyle, config) {
                        return Table(
                          children: tableRows.map((e) {
                            return TableRow(
                              children: e.fields.map((e) {
                                return Text(e.data,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium);
                              }).toList(),
                            );
                          }).toList(),
                        );
                      },
                    ),
                    SizedBox(
                      height: Dimens.marginLarge,
                    ),
                    GptMarkdown(apostrophe)
                  ]))),
    );
  }
}

const String alphabet = '''
| | | |
| ---|---|---|
| 1. A|father|afke (hominy grits)|
| 2. C|such|cesse (mouse)|
| 3. E|fit|ecke (mother)|
| |feed|ecko (dried corn)|
| 4. F|as in English|fuswv (bird)|
| 5. H|as in English|hvse (sun)|
| 6. I|hey|ehiwv (his wife)|
| 7. K|ski|kapv (coat)|
| 8. L|as in English|lucv (turtle)|
| 9. M|as in English|meske (summer)|
| 10. N|as in English|nere (night)|
| 11. O|rode|ofv (inside)|
| 12. P|pen|penwv (turkey)|
| 13. R|athlete|rvro (fish)|
| 14. S|as in English|sukhv (hog)|
| 15. T|steam|este (person)|
| 16. U|food|fuswv (bird)|
| 17. V|ago|vce (corn)|
| 18. W|as in English|wotko (raccoon)|
| 19. Y|as in English|yvnvsv (buffalo)|
* A, E, I, O, U, & V are vowels.
''';

const String copyright = '''
[Maketskēs / You can say it, Chapter 2.](https://pressbooks.pub/maskoke/chapter/the-alphabet/) 
Copyright © by Linda Sulphur Bear and Jack B. Martin.

''';

const String dipthongs = '''
|Diphthongs|
|---|---|
|AE|as in aeha |
|EU|as in cemeu|
|OU|as in cukou|
|UE|as in uewv|
''';

const String apostrophe = '''
### Mvskoke Apostrophe 

In Mvskoke Hymns, when the letter O has an apostrophe after it, the apostrophe indicates a double O, holding or lengthening the O for emphasis. Example: O Vwacken O' Vwacken, Translation: O come O o come. Additionally, when a word ending in a vowel is followed by a word beginning with a vowel, one of those vowels is generally dropped for the sake of euphony. For example: Mekusapvlke vpeyvnna - Mekusapvlk' vpeyvnna. The Christians have gone on. 

In the Mvskoke language, prefixes such as Cv, Ce, and E are added to words to show possession. When a prefix is added to a word that begins with a vowel, the vowel is generally dropped. Examples erke - father, cv'rke - my father, ce'rke - your father, e'rke - his, her or its father.
''';
