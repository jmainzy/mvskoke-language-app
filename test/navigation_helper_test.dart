import 'package:flutter_test/flutter_test.dart';
import 'package:mvskoke_language_app/services/navigation_helper.dart';

void main() {
  test('content page path includes the encoded story id', () {
    expect(
      NavigationHelper.contentPagePath('story 123'),
      '/content/story%20123',
    );
  });
}
