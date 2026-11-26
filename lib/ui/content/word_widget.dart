import 'package:material_ui/material_ui.dart';
import 'package:mvskoke_language_app/models/word.dart';

class WordWidget extends StatelessWidget {
  final Word word;
  final VoidCallback? onHide;

  const WordWidget({super.key, required this.word, this.onHide});

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (_) => onHide?.call(),
      child: Material(
        key: const ValueKey('word-definition'),
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onHide,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    word.headword,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  for (var entry in word.entries.values.expand((e) => e))
                    Text(entry),
                  if (word.definition case final definition?) Text(definition),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
