import 'dart:io';

import 'package:flutter/foundation.dart';

bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
bool get isNotMobile => kIsWeb || !isMobile;
