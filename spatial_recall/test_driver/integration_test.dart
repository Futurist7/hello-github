// Driver for running integration_test in profile/release-like (AOT) mode:
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_test.dart --profile -d <device-id>
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
