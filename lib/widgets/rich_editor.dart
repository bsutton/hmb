import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fleather/fleather.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:parchment_delta/parchment_delta.dart';
import 'package:strings/strings.dart';
import 'package:url_launcher/url_launcher.dart';

class RichEditorController {
  /// [parchmentAsJsonString] contains the parchment
  /// encode as json then encoded to a string.
  RichEditorController({required String parchmentAsJsonString}) {
    _initController(parchmentAsJsonString);
  }

  late ParchmentDocument document;
  late final FleatherController controller;

  TextSelection get selection => controller.selection;

  void _initController(String parchmentAsJsonString) {
    try {
      // define heuristics - these where just taken
      // from the example and are probably not needed.
      document = RichEditor.createParchment(parchmentAsJsonString);
      controller = FleatherController(document: document);
      // ignore: avoid_catches_without_on_clauses
    } catch (err, st) {
      print('Unable to load parchment into RichEditor: $err\n$st');
      controller = FleatherController();
    }
  }

  void replaceText(int index, int length, Object data,
      {TextSelection? selection}) {
    controller.replaceText(index, length, data, selection: selection);
  }

  void dispose() {
    controller.dispose();
  }
}

class RichEditor extends StatefulWidget {
  const RichEditor(
      {required this.controller, required this.focusNode, super.key});

  final RichEditorController controller;
  final FocusNode focusNode;

  @override
  State<RichEditor> createState() => _RichEditorState();

  /// Generates a [ParchmentDocument] from a json string that contains
  /// a json encoded Parchment.
  static ParchmentDocument createParchment(String parchmentAsJsonString) {
    List<dynamic>? json;

    if (Strings.isEmpty(parchmentAsJsonString)) {
      json = null;
    } else {
      try {
        json =jsonDecode(parchmentAsJsonString) as List<dynamic>;
      } on FormatException catch (err, _) {
        print('Error parsing json, err: $err  data: $parchmentAsJsonString');
      }
    }

    // define heuristics - these where just taken
    // from the example and are probably not needed.
    final heuristics = ParchmentHeuristics(
      formatRules: [],
      insertRules: [
        ForceNewlineForInsertsAroundInlineImageRule(),
      ],
      deleteRules: [],
    ).merge(ParchmentHeuristics.fallback);
    // create the parchment

    ParchmentDocument doc;
    if (json == null) {
      /// Either no json or invalid json passed
      /// so create an empty document.
      doc = ParchmentDocument(
        heuristics: heuristics,
      );
    } else {
      doc = ParchmentDocument.fromJson(
        json,
        heuristics: heuristics,
      );
    }
    return doc;
  }
}

class _RichEditorState extends State<RichEditor> {
  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      unawaited(BrowserContextMenu.disableContextMenu());
    }
  }

  @override
  void dispose() {
    super.dispose();
    if (kIsWeb) {
      unawaited(BrowserContextMenu.enableContextMenu());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final picker = ImagePicker();
            final image = await picker.pickImage(source: ImageSource.gallery);
            if (image != null) {
              final selection = widget.controller.selection;
              widget.controller.replaceText(
                selection.baseOffset,
                selection.extentOffset - selection.baseOffset,
                EmbeddableObject('image', inline: false, data: {
                  'source_type': kIsWeb ? 'url' : 'file',
                  'source': image.path,
                }),
              );
              widget.controller.replaceText(
                selection.baseOffset + 1,
                0,
                '\n',
                selection:
                    TextSelection.collapsed(offset: selection.baseOffset + 2),
              );
            }
          },
          child: const Icon(Icons.add_a_photo),
        ),
        body: FocusScope(
          node: FocusScopeNode(),
          child: Column(
            children: [
              FleatherToolbar.basic(controller: widget.controller.controller),
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
              Expanded(
                child: FleatherEditor(
                  key: UniqueKey(),
                  controller: widget.controller.controller,
                  focusNode: widget.focusNode,
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.of(context).padding.bottom,
                  ),
                  onLaunchUrl: _launchUrl,
                  embedBuilder: _embedBuilder,
                  spellCheckConfiguration: _getSpellCheckService(context),
                ),
              ),
            ],
          ),
        ),
      );

  /// Spell checker only supported on Android and iOS.
  SpellCheckConfiguration? _getSpellCheckService(BuildContext context) {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      return SpellCheckConfiguration(
          spellCheckService: DefaultSpellCheckService(),
          misspelledSelectionColor: Colors.red,
          misspelledTextStyle: DefaultTextStyle.of(context).style);
    } else {
      return null;
    }
  }

  Widget _embedBuilder(BuildContext context, EmbedNode node) {
    if (node.value.type == 'icon') {
      final data = node.value.data;
      // Icons.rocket_launch_outlined
      return Icon(
        IconData(int.parse(data['codePoint'] as String),
            fontFamily: data['fontFamily'] as String),
        color: Color(int.parse(data['color'] as String)),
        size: 18,
      );
    }

    if (node.value.type == 'image') {
      final sourceType = node.value.data['source_type'];
      ImageProvider? image;
      if (sourceType == 'assets') {
        image = AssetImage(node.value.data['source'] as String);
      } else if (sourceType == 'file') {
        image = FileImage(File(node.value.data['source'] as String));
      } else if (sourceType == 'url') {
        image = NetworkImage(node.value.data['source'] as String);
      }
      if (image != null) {
        return Padding(
          // Caret takes 2 pixels, hence not symmetric padding values.
          padding: const EdgeInsets.only(left: 4, right: 2, top: 2, bottom: 2),
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              image: DecorationImage(image: image, fit: BoxFit.cover),
            ),
          ),
        );
      }
    }

    return defaultFleatherEmbedBuilder(context, node);
  }

  Future<void> _launchUrl(String? url) async {
    if (url == null) {
      return;
    }
    final uri = Uri.parse(url);
    final _canLaunch = await canLaunchUrl(uri);
    if (_canLaunch) {
      await launchUrl(uri);
    }
  }
}

/// This is an example insert rule that will insert a new line before and
/// after inline image embed.
class ForceNewlineForInsertsAroundInlineImageRule extends InsertRule {
  @override
  Delta? apply(Delta document, int index, Object data) {
    if (data is! String) {
      return null;
    }

    final iter = DeltaIterator(document);
    final previous = iter.skip(index);
    final target = iter.next();
    final cursorBeforeInlineEmbed = _isInlineImage(target.data);
    final cursorAfterInlineEmbed =
        previous != null && _isInlineImage(previous.data);

    if (cursorBeforeInlineEmbed || cursorAfterInlineEmbed) {
      final delta = Delta()..retain(index);
      if (cursorAfterInlineEmbed && !data.startsWith('\n')) {
        delta.insert('\n');
      }
      delta.insert(data);
      if (cursorBeforeInlineEmbed && !data.endsWith('\n')) {
        delta.insert('\n');
      }
      return delta;
    }
    return null;
  }

  bool _isInlineImage(Object data) {
    if (data is EmbeddableObject) {
      return data.type == 'image' && data.inline;
    }
    if (data is Map) {
      return data[EmbeddableObject.kTypeKey] == 'image' &&
          data[EmbeddableObject.kInlineKey] as bool;
    }
    return false;
  }
}
