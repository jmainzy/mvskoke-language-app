import 'package:hive/hive.dart';

class StoreService {
  late Box box;
  StoreService(this.box);

  @override
  double get fontSize => box.get('font_size', defaultValue: 18.0);

  double get fontScale => fontSize / 18.0;

  @override
  Future<void> setFontSize(double value) {
    box.put('font_size', value);
    return Future.value();
  }
}

// class TestStoreService extends StoreService {
//   /// This is a test store service that does not use Hive.
//   TestStoreService() : super();

//   @override
//   double get fontSize => 20;

//   @override
//   Future<void> setFontSize(double value) => Future.value();
// }
