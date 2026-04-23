import 'package:flutter/material.dart';

/// Global scaffold messenger key used to show SnackBars/MaterialBanners
/// from anywhere in the app (including widgets that aren't inside a specific Scaffold).
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
