/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

// ignore_for_file: deprecated_member_use

import 'package:intl/intl.dart';
import 'package:logger/logger.dart' hide AnsiColor;
import 'package:stacktrace_impl/stacktrace_impl.dart';

import 'ansi_color.dart';

/// Logging class
class Log extends Logger {
  static late Log _self;
  static late String _localPath;
  static final _recentLogs = <String, DateTime>{};
  /// The default log level.
  static Level loggingLevel = Level.debug;

  Log();

  Log._internal(String currentWorkingDirectory)
    : super(printer: MyLogPrinter(currentWorkingDirectory));

  ///
  factory Log.color(
    String message,
    AnsiColor color, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    autoInit();
    _self.d(color.apply(message), error: error, stackTrace: stackTrace);
    return _self;
  }

  ///
  factory Log.d(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    bool supressDuplicates = false,
  }) {
    autoInit();
    var suppress = false;

    if (supressDuplicates) {
      final lastLogged = _recentLogs[message];
      if (lastLogged != null &&
          lastLogged
              .add(const Duration(milliseconds: 100))
              .isAfter(DateTime.now())) {
        suppress = true;
      }
      _recentLogs[message] = DateTime.now();
    }
    if (!suppress) {
      _self.d(message, error: error, stackTrace: stackTrace);
    }
    return _self;
  }

  ///
  factory Log.i(String message, {dynamic error, StackTrace? stackTrace}) {
    autoInit();
    _self.i(message, error: error, stackTrace: stackTrace);
    return _self;
  }

  ///
  factory Log.w(String message, {dynamic error, StackTrace? stackTrace}) {
    autoInit();
    _self.w(message, error: error, stackTrace: stackTrace);
    return _self;
  }

  ///
  factory Log.e(String message, {dynamic error, StackTrace? stackTrace}) {
    autoInit();
    _self.e(message, error: error, stackTrace: stackTrace);
    return _self;
  }

  ///
  void debug(String message, {dynamic error, StackTrace? stackTrace}) {
    autoInit();
    Log.d(message, error: error, stackTrace: stackTrace);
  }

  ///
  void info(String message, {dynamic error, StackTrace? stackTrace}) {
    autoInit();
    Log.i(message, error: error, stackTrace: stackTrace);
  }

  ///
  void warn(String message, {dynamic error, StackTrace? stackTrace}) {
    autoInit();
    Log.w(message, error: error, stackTrace: stackTrace);
  }

  ///
  void error(String message, {dynamic error, StackTrace? stackTrace}) {
    autoInit();
    Log.e(message, error: error, stackTrace: stackTrace);
  }

  ///
  void color(
    String message,
    AnsiColor color, {
    dynamic error,
    StackTrace? stackTrace,
  }) {
    autoInit();
    Log.i(color.apply(message), error: error, stackTrace: stackTrace);
  }

  static void autoInit() {}

  /// Call this method to prep the logger so that we
  static void configure(String currentWorkingDirectory) {
    _self = Log._internal(currentWorkingDirectory);

    final frames = StackTraceImpl();

    for (final frame in frames.frames) {
      _localPath = frame.sourceFile.path.substring(
        frame.sourceFile.path.lastIndexOf('/'),
      );
      break;
    }
  }
}

///
class MyLogPrinter extends LogPrinter {
  ///
  String currentWorkingDirectory;

  ///
  MyLogPrinter(this.currentWorkingDirectory);

  @override
  List<String> log(LogEvent event) {
    if (Log.loggingLevel.index > event.level.index) {
      // don't log events where the log level is set higher
      return [];
    }
    final formatter = DateFormat('dd HH:mm:ss.');
    final now = DateTime.now();
    final formattedDate = formatter.format(now) + now.millisecond.toString();

    final frames = StackTraceImpl();
    var i = 0;
    var depth = 0;
    for (final frame in frames.frames) {
      i++;
      final path2 = frame.sourceFile.path;
      if (!path2.contains(Log._localPath) && !path2.contains('logger.dart')) {
        depth = i - 1;
        break;
      }
    }

    final frame = StackTraceImpl(skipFrames: depth).frames[0];

    var details = frame.details;
    if (details != null && details.contains('closure')) {
      details = '<closure>';
    }

    final line = '${frame.sourceFile} : $details : ${frame.lineNo}';

    print(
      color(
        event.level,
        '$formattedDate ${event.level.name} '
        '| $line'
        '::: ${event.message}',
      ),
    );

    if (event.error != null) {
      print(color(event.level, '${event.error}'));
    }

    if (event.stackTrace != null) {
      if (event.stackTrace.runtimeType == StackTraceImpl) {
        final st = event.stackTrace! as StackTraceImpl;
        print(color(event.level, '$st'));
      } else {
        print(color(event.level, '${event.stackTrace}'));
      }
    }
    return [];
  }

  ///
  String color(Level level, String line) {
    var result = '';

    switch (level) {
      case Level.debug:
        result += grey(line, level: 0.75);
      case Level.verbose:
        result += grey(line);
      case Level.info:
        result += line;
      case Level.warning:
        result += orange(line);
      case Level.error:
        result += red(line);
      case Level.wtf:
        result += red(line, bgcolor: AnsiColor.yellow);
      case Level.nothing:
        result += line;
      case Level.all:
        result += line;
      case Level.trace:
        result += line;
      case Level.fatal:
        result += red(line);
      case Level.off:
        break;
    }

    return result;
  }
}
