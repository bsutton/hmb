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

/// Returns a string wrapped with the selected ansi
/// fg color codes.
library;
// ignore_for_file: prefer_constructors_over_static_methods

String red(String text, {AnsiColor bgcolor = AnsiColor.none}) =>
    AnsiColor._apply(AnsiColor.red, text, bgcolor: bgcolor);

///
String black(String text, {AnsiColor bgcolor = AnsiColor.white}) =>
    AnsiColor._apply(AnsiColor.black, text, bgcolor: bgcolor);

///
String green(String text, {AnsiColor bgcolor = AnsiColor.none}) =>
    AnsiColor._apply(AnsiColor.green, text, bgcolor: bgcolor);

///
String blue(String text, {AnsiColor bgcolor = AnsiColor.none}) =>
    AnsiColor._apply(AnsiColor.blue, text, bgcolor: bgcolor);

///
String yellow(String text, {AnsiColor bgcolor = AnsiColor.none}) =>
    AnsiColor._apply(AnsiColor.yellow, text, bgcolor: bgcolor);

///
String magenta(String text, {AnsiColor bgcolor = AnsiColor.none}) =>
    AnsiColor._apply(AnsiColor.magenta, text, bgcolor: bgcolor);

///
String cyan(String text, {AnsiColor bgcolor = AnsiColor.none}) =>
    AnsiColor._apply(AnsiColor.cyan, text, bgcolor: bgcolor);

///
String white(String text, {AnsiColor bgcolor = AnsiColor.none}) =>
    AnsiColor._apply(AnsiColor.white, text, bgcolor: bgcolor);

///
String orange(String text, {AnsiColor bgcolor = AnsiColor.none}) =>
    AnsiColor._apply(AnsiColor.orange, text, bgcolor: bgcolor);

///
String grey(
  String text, {
  double level = 0.5,
  AnsiColor bgcolor = AnsiColor.none,
}) => AnsiColor._apply(AnsiColor.grey(level: level), text, bgcolor: bgcolor);

///
class AnsiColor {
  /// ANSI Control Sequence Introducer, signals the terminal for new settings.
  static const esc = '\x1B[';

  /// Resets

  /// Reset fg and bg colors
  static const resetCode = '0';

  /// Defaults the terminal's fg color without altering the bg.
  static const fgResetCode = '39';

  /// Defaults the terminal's bg color without altering the fg.
  static const bgResetCode = '49';

  /// emmit this code followed by a color code to set the fg color
  static const fgColor = '38;5;';

  /// emmit this code followed by a color code to set the fg color
  static const bgColor = '48;5;';

  /// Colors
  static const black = AnsiColor(30);

  ///
  static const red = AnsiColor(31);

  ///
  static const green = AnsiColor(32);

  ///
  static const yellow = AnsiColor(33);

  ///
  static const blue = AnsiColor(34);

  ///
  static const magenta = AnsiColor(35);

  ///
  static const cyan = AnsiColor(36);

  ///
  static const white = AnsiColor(37);

  ///
  static const orange = AnsiColor(208);

  /// passing this as the background color will cause
  /// the background code to be suppressed resulting
  /// in the default background color.
  static const none = AnsiColor(-1);

  final int _code;

  ///
  const AnsiColor(int code) : _code = code;

  ///
  static AnsiColor grey({double level = 0.5}) =>
      AnsiColor(232 + (level.clamp(0.0, 1.0) * 23).round());

  ///
  static String reset() => _emmit(resetCode);

  ///
  static String fgReset() => _emmit(fgResetCode);

  ///
  static String bgReset() => _emmit(bgResetCode);

  ///
  int get code => _code;

  ///
  String apply(String text, {AnsiColor bgcolor = none}) =>
      _apply(this, text, bgcolor: bgcolor);

  static String _apply(
    AnsiColor color,
    String text, {
    AnsiColor bgcolor = none,
  }) => '${_fg(color.code)}${_bg(bgcolor.code)}$text$_reset';

  static String get _reset => '$esc${resetCode}m';

  static String _fg(int code) {
    String output;

    if (code == none.code) {
      output = '';
    } else if (code > 39) {
      output = '$esc$fgColor${code}m';
    } else {
      output = '$esc${code}m';
    }
    return output;
  }

  // background colors are fg color + 10
  static String _bg(int code) {
    String output;

    if (code == none.code) {
      output = '';
    } else if (code > 49) {
      output = '$esc$bgColor${code + 10}m';
    } else {
      output = '$esc${code + 10}m';
    }
    return output;
  }

  static String _emmit(String ansicode) => '$esc${ansicode}m';
}
