import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../widgets/hmb_button.dart';

class HMBFilePickerDialog {
  Future<String?> show(
    BuildContext context, {
    List<String>? allowedExtensions,
    bool showHidden = false,
  }) => _pickFileFromDirectory(
    context,
    Directory.current,
    allowedExtensions: allowedExtensions,
    showHidden: showHidden,
  );

  Future<String?> _pickFileFromDirectory(
    BuildContext context,
    Directory directory, {
    List<String>? allowedExtensions,
    bool showHidden = false,
  }) async {
    String? selectedFilePath;

    await showDialog<void>(
      context: context,
      builder: (context) => _FilePickerDialog(
        directory: directory,
        allowedExtensions: allowedExtensions,
        showHidden: showHidden,
        onFileSelected: (filePath) {
          selectedFilePath = filePath;
          Navigator.pop(context);
        },
      ),
    );

    return selectedFilePath;
  }
}

class _FilePickerDialog extends StatefulWidget {
  const _FilePickerDialog({
    required this.directory,
    required this.onFileSelected,
    this.allowedExtensions,
    this.showHidden = false,
  });

  final Directory directory;
  final ValueChanged<String> onFileSelected;
  final List<String>? allowedExtensions;
  final bool showHidden;

  @override
  __FilePickerDialogState createState() => __FilePickerDialogState();
}

class __FilePickerDialogState extends State<_FilePickerDialog> {
  late Directory _currentDirectory;
  List<FileSystemEntity> _files = [];

  @override
  void initState() {
    super.initState();
    _currentDirectory = widget.directory;
    _listFiles();
  }

  void _listFiles() {
    setState(() {
      _files = _currentDirectory.listSync().where((entity) {
        final isHidden = p.basename(entity.path).startsWith('.');

        if (!widget.showHidden && isHidden) {
          return false;
        }

        if (entity is File) {
          if (widget.allowedExtensions != null) {
            final extension = p
                .extension(entity.path)
                .toLowerCase()
                .replaceAll('.', '');
            return widget.allowedExtensions!.contains(extension);
          }
        }

        return true;
      }).toList();
    });
  }

  void _navigateToParent() {
    setState(() {
      _currentDirectory = _currentDirectory.parent;
      _listFiles();
    });
  }

  void _navigateToDirectory(Directory directory) {
    setState(() {
      _currentDirectory = directory;
      _listFiles();
    });
  }

  List<BreadcrumbItem> _buildBreadcrumbs() {
    final items = <BreadcrumbItem>[];
    var dir = _currentDirectory;
    while (true) {
      final directoryName = dir.path == dir.parent.path
          ? '/'
          : p.basename(dir.path);
      items.insert(0, BreadcrumbItem(directoryName, dir));
      if (dir.path == dir.parent.path) {
        break;
      }
      dir = dir.parent;
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final breadcrumbs = _buildBreadcrumbs();
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select a File'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: breadcrumbs
                  .map(
                    (breadcrumb) => GestureDetector(
                      onTap: () => _navigateToDirectory(breadcrumb.directory),
                      child: Row(
                        children: [
                          Text(breadcrumb.name),
                          if (breadcrumb != breadcrumbs.last) const Text(' / '),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          itemCount: _files.length,
          itemBuilder: (context, index) {
            final entity = _files[index];
            return ListTile(
              leading: entity is Directory
                  ? const Icon(Icons.folder)
                  : const Icon(Icons.insert_drive_file),
              title: Text(p.basename(entity.path)),
              onTap: () {
                if (entity is Directory) {
                  _navigateToDirectory(entity);
                } else if (entity is File) {
                  widget.onFileSelected(entity.path);
                }
              },
            );
          },
        ),
      ),
      actions: [
        if (_currentDirectory.path != _currentDirectory.parent.path)
          HMBButton(label: 'Up', onPressed: _navigateToParent),
        HMBButton(label: 'Cancel', onPressed: () => Navigator.pop(context)),
      ],
    );
  }
}

class BreadcrumbItem {
  BreadcrumbItem(this.name, this.directory);
  final String name;
  final Directory directory;
}
