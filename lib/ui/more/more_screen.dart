import 'package:flutter/material.dart';
import 'package:mvskoke_language_app/services/navigation_helper.dart';
import 'package:mvskoke_language_app/utilities/dimens.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            MoreItem(
              title: 'About',
              icon: Icons.info,
              onTap: () {
                NavigationHelper.router.go(
                  '${NavigationHelper.morePath}/${NavigationHelper.aboutPath}',
                );
              },
            ),
            MoreItem(
              title: 'Glossary',
              icon: Icons.book,
              onTap: () {
                NavigationHelper.router.go(
                  '${NavigationHelper.morePath}/${NavigationHelper.glossaryPath}',
                );
              },
            ),
            MoreItem(
              title: 'Mvskoke Alphabet',
              icon: Icons.abc,
              onTap: () {
                NavigationHelper.router.go(
                  '${NavigationHelper.morePath}/${NavigationHelper.alphabetPath}',
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class MoreItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const MoreItem({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Dimens.marginLarge,
        vertical: Dimens.marginShort,
      ),
      title: Text(title),
      leading: Icon(icon),
      onTap: onTap,
    );
  }
}
