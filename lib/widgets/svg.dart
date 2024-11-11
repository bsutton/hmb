import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum LOCATION { vaadin, icons }

class Svg extends StatelessWidget {
  ///
  /// We are having sizing problems.
  /// The aim is to have the SVG fill its parent if the width/height are not specified.
  /// The issue is that if a column(?) with infinite height if we don't
  /// provide a hieght we get a nasty error out of flutter (even though the svg
  /// renders as expected).
  /// The default sizes here are a hack around the problem.
  ///
  const Svg(this.filename,
      {super.key,
      this.label,
      this.width = 80,
      this.height = 80,
      this.location = LOCATION.icons,
      this.onTap,
      this.color});
  final String filename;
  final String? label;
  final double width;
  final double height;
  final LOCATION location;
  final void Function()? onTap;
  final Color? color;

  static const vaadinAsset = 'assets/vaadin-svg/';
  static const iconAsset = 'assets/icons/';

  @override
  Widget build(BuildContext context) => buildSvg();

/*
    return FittedBox(`
      fit: BoxFit.scaleDown,
      child: buildTree()

    );
    */
  Widget buildSvg() =>
      SizedBox(width: width, height: height, child: buildTree());

  Widget buildTree() => GestureDetector(onTap: onTap, child: buildAsset());

  Widget buildAsset() {
    final finalPath = getPath(filename);
    return SvgPicture.asset(finalPath,
        semanticsLabel: label,
        width: width,
        height: height,
        colorFilter: ColorFilter.mode(color!, BlendMode.src));
  }

  String getPath(String filename) {
    String path;
    switch (location) {
      case LOCATION.vaadin:
        path = vaadinAsset;
      case LOCATION.icons:
        path = iconAsset;
    }

    var extension = '';
    if (!filename.endsWith('.svg')) {
      extension = '.svg';
    }

    return path + filename + extension;
  }
}
