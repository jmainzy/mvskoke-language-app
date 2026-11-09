import 'package:flutter/material.dart';
import 'package:mvskoke_language_app/utilities/dimens.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  AboutScreenState createState() => AboutScreenState();
}

class AboutScreenState extends State<AboutScreen> with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  late final Future<PackageInfo> packageInfoFuture;

  @override
  void initState() {
    super.initState();
    packageInfoFuture = PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: Padding(
        padding: EdgeInsets.all(Dimens.marginLarge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<PackageInfo>(
              future: packageInfoFuture,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Unable to load app version: ${snapshot.error}');
                }
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }
                final packageInfo = snapshot.data!;
                return Text(
                  'Version ${packageInfo.version} '
                  '(build ${packageInfo.buildNumber})',
                );
              },
            ),
            const SizedBox(height: 16),
            const Text('Built by: \n(c) 2026 Nativeware Solutions, LLC.'),
          ],
        ),
      ),
    );
  }
}
