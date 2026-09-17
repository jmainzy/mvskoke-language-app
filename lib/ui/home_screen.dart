import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:watch_it/watch_it.dart' hide sl;

Logger log = Logger();

class HomeScreen extends WatchingStatefulWidget {
  final String? shortId;
  const HomeScreen({super.key, this.shortId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Center(child: Text('Home')),
    );
  }
}
