import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../util/hmb_theme.dart';

/// To be used as the page specific title
class HMBPageTitle extends StatelessWidget {
  const HMBPageTitle(this.text,
      {super.key, this.color = HMBColors.textPrimary});
  final String text;
  final Color color;
  static const fontSize = 26.0;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('text', text))
      ..add(ColorProperty('color', color));
  }
}

class HMBCardTitle extends StatelessWidget {
  const HMBCardTitle(this.text,
      {super.key, this.color = HMBColors.textPrimary});
  final String text;
  final Color color;
  static const fontSize = 22.0;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('text', text))
      ..add(ColorProperty('color', color));
  }
}

/// The first heading withing the body of the card.
class HMBCardHeading extends StatelessWidget {
  const HMBCardHeading(this.text,
      {super.key, this.color = HMBColors.textPrimary});
  final String text;
  final Color color;
  static const fontSize = 20.0;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis, // Handle overflow
          maxLines: 1, // Limit to one line
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('text', text))
      ..add(ColorProperty('color', color));
  }
}

///
/// Use this style on any page that has a full width heading at the
/// top of the page.
///
class HMBTextPageHeading extends StatelessWidget {
  HMBTextPageHeading(String text,
      {super.key, this.color = HMBColors.textPrimary})
      : text = text.toUpperCase();
  final String text;
  final Color color;
  static const fontSize = 30.0;

  @override
  Widget build(BuildContext context) => FittedBox(
      fit: BoxFit.fitWidth,
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: fontSize, fontWeight: FontWeight.w500)));
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('text', text))
      ..add(ColorProperty('color', color));
  }
}

class HMBTextHeadline extends StatelessWidget {
  const HMBTextHeadline(this.text,
      {super.key, this.color = HMBColors.textPrimary});
  final String text;
  final Color color;
  static const fontSize = 30.0;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('text', text))
      ..add(ColorProperty('color', color));
  }
}

class HMBTextHeadline2 extends StatelessWidget {
  const HMBTextHeadline2(this.text,
      {super.key, this.color = HMBColors.textPrimary});
  final String text;
  final Color color;
  static const fontSize = 26.0;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis, // Handle overflow
          maxLines: 1, // Limit to one line
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('text', text))
      ..add(ColorProperty('color', color));
  }
}

class HMBTextHeadline3 extends StatelessWidget {
  HMBTextHeadline3(this.text, {super.key, this.color = HMBColors.textPrimary})
      : style = TextStyle(fontSize: fontSize, color: color);
  final String text;
  final Color color;
  static const fontSize = 22.0;

  final TextStyle style;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(text, style: style),
      );
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('text', text))
      ..add(ColorProperty('color', color))
      ..add(DiagnosticsProperty<TextStyle>('style', style));
  }
}

/// Use this for a section heading within the body of a document
/// This is normally used as a heading for a paragraph which
/// uses the TextHMBBody style.
class HMBTextSectionHeading extends StatelessWidget {
  HMBTextSectionHeading(this.text,
      {super.key, this.color = HMBColors.textPrimary})
      : style = TextStyle(
            fontSize: fontSize, color: color, fontWeight: FontWeight.bold);
  final String text;
  final Color color;
  static const fontSize = 18.0;

  final TextStyle style;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(10), child: Text(text, style: style));
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('text', text))
      ..add(ColorProperty('color', color))
      ..add(DiagnosticsProperty<TextStyle>('style', style));
  }
}

///
/// Used for text and  paragraphs of text that should use the
///  standard font/styling for the body of a document.
class HMBTextBody extends StatelessWidget {
  HMBTextBody(this.text, {super.key, this.color = HMBColors.textPrimary})
      : _style = style.copyWith(color: color);
  static const fontSize = 16.0;
  static const TextStyle style = TextStyle(fontSize: fontSize);

  final TextStyle _style;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text(text, style: _style),
      );
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('text', text))
      ..add(ColorProperty('color', color));
  }
}

/// Use for text in a body section that needs to be bold.
class HMBTextBodyBold extends StatelessWidget {
  HMBTextBodyBold(this.text, {super.key, this.color = HMBColors.textPrimary})
      : style = TextStyle(
            color: color, fontSize: fontSize, fontWeight: FontWeight.bold);
  final String text;
  final Color color;
  final TextStyle style;
  static const fontSize = 16.0;

  @override
  Widget build(BuildContext context) => Text(text, style: style);
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('text', text))
      ..add(ColorProperty('color', color))
      ..add(DiagnosticsProperty<TextStyle>('style', style));
  }
}

///
/// Used in the body of a document where you need to
/// highlight the text. This is essentially a bolded TextHMBBody
///
class HMBTextNotice extends StatelessWidget {
  const HMBTextNotice(this.text, {super.key});
  static const fontSize = 14.0;
  final String text;
  static const TextStyle noticeStyle =
      TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold);

  @override
  Widget build(BuildContext context) => Text(text, style: noticeStyle);
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('text', text));
  }
}

///
/// Used when you need to display text indicating an error.
///
class HMBTextError extends StatelessWidget {
  const HMBTextError(this.text, {super.key});
  static const fontSize = 14.0;
  final String text;
  static const TextStyle noticeStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      color: HMBColors.errorText,
      backgroundColor: HMBColors.errorBackground);

  @override
  Widget build(BuildContext context) => Text(text, style: noticeStyle);
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('text', text));
  }
}

///
/// Text style used by buttons such as ButtonPrimary/ButtonSecondary
///
class HMBTextButton extends StatelessWidget {
  HMBTextButton(this.text, {super.key, this.color = HMBColors.textPrimary})
      : style = TextStyle(color: color, fontSize: fontSize);
  static const fontSize = 16.0;
  final String text;
  final Color color;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(4),
        child: Text(text.toUpperCase(), style: style),
      );
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('text', text))
      ..add(ColorProperty('color', color))
      ..add(DiagnosticsProperty<TextStyle>('style', style));
  }
}

/// Use for Form Field labels.
class HMBTextLabel extends StatelessWidget {
  HMBTextLabel(this.text, {super.key, this.color = HMBColors.textPrimary})
      : style = TextStyle(color: color, fontSize: fontSize);
  static const fontSize = 16.0;
  final String text;
  final Color color;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Text(text, style: style);
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('text', text))
      ..add(ColorProperty('color', color))
      ..add(DiagnosticsProperty<TextStyle>('style', style));
  }
}

///
/// Use this for text that is displayed in the likes of a ListView
///
class HMBTextListItem extends StatelessWidget {
  const HMBTextListItem(this.text,
      {super.key, this.color = HMBColors.listCardText});
  final String text;
  final Color? color;
  static const fontSize = 16.0;
  static const TextStyle style = TextStyle(fontSize: fontSize);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: style.copyWith(color: color));
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('text', text))
      ..add(ColorProperty('color', color));
  }
}

///
/// Use this for text that is displayed in the likes of a ListView
///
class HMBTextListItemBold extends StatelessWidget {
  const HMBTextListItemBold(this.text,
      {super.key, this.color = HMBColors.listCardText});
  static const fontSize = 16.0;
  final String text;
  final Color color;
  static const TextStyle style =
      TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: style.copyWith(color: color));
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('text', text))
      ..add(ColorProperty('color', color));
  }
}

///
/// Use this style when you are looking to display
/// some ancillary information that isn't that important.
/// Ancillary text will be displayed in a lighter font color
class HMBUTextAncillary extends StatelessWidget {
  HMBUTextAncillary(this.text, {super.key, this.color = Colors.grey})
      : style = TextStyle(color: color, fontSize: fontSize);
  static const fontSize = 16.0;
  final String text;
  final Color color;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(8), child: Text(text, style: style));
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('text', text))
      ..add(ColorProperty('color', color))
      ..add(DiagnosticsProperty<TextStyle>('style', style));
  }
}

///
/// Used for the text within chips.
class HMBTextChip extends StatelessWidget {
  HMBTextChip(this.text, {super.key, this.color = HMBColors.chipTextColor})
      : _style = style.copyWith(color: color);
  static const fontSize = 15.0;
  static const TextStyle style = TextStyle(fontSize: fontSize);

  final TextStyle _style;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(text, style: _style);
  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('text', text))
      ..add(ColorProperty('color', color));
  }
}

enum Position { start, end }

class HMBTextIcon extends StatelessWidget {
  const HMBTextIcon(this.text, this.icon,
      {super.key, this.position = Position.start, this.iconColor, this.color});
  static const fontSize = HMBTextListItem.fontSize;
  final String text;
  final IconData icon;
  final Position position;
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    if (position == Position.start) {
      return Row(children: [
        Icon(icon, color: iconColor),
        Padding(
            padding: const EdgeInsets.only(left: 5),
            child: HMBTextListItem(text, color: color))
      ]);
    } else {
      return Row(children: [
        Padding(
            padding: const EdgeInsets.only(right: 5),
            child: HMBTextListItem(text, color: color)),
        Icon(icon, color: iconColor)
      ]);
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(StringProperty('text', text))
      ..add(DiagnosticsProperty<IconData>('icon', icon))
      ..add(EnumProperty<Position>('position', position))
      ..add(ColorProperty('color', color))
      ..add(ColorProperty('iconColor', iconColor));
  }
}
