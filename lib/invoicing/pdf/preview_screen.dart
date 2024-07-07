import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PdfPreviewScreen extends StatelessWidget {
  const PdfPreviewScreen(
      {required this.filePath, required this.title, super.key});
  final String filePath;
  final String title;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(title),
        ),
        body: PdfViewer.file(
          filePath,
        ),
      );
}
