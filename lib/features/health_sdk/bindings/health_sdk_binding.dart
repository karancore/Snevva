import 'package:get/get.dart';

import '../controllers/health_sdk_controller.dart';

/// Registers [HealthSdkController] lazily with fenix so GetX recreates it
/// if the route is revisited after the controller was garbage-collected.
class HealthSdkBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HealthSdkController>(
      () => HealthSdkController(),
      fenix: true,
    );
  }
}