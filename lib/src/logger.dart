import 'package:logging/logging.dart';

final rclDartLogger = Logger('rcldart');
void initLogger() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });
}
