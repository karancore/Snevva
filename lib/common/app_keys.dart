import 'package:flutter/material.dart';

/// Global navigator key used by GetMaterialApp so that navigation and
/// overlay operations can be performed without a [BuildContext].
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
