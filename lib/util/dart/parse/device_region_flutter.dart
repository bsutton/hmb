import 'dart:ui';

String? deviceRegion() => PlatformDispatcher.instance.locale.countryCode;
