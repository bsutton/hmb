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

import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../widgets/fields/hmb_text_field.dart';
import '../widgets/hmb_button.dart';
import '../widgets/layout/layout.g.dart';

class HMBFilePickerDialog {
  Future<String?> show(
    BuildContext context, {
    List<String>? allowedExtensions,
    bool showHidden = false,
    Directory? initialDirectory,
  }) => _pickFileFromDirectory(
    context,
    initialDirectory ?? Directory.current,
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
  final Directory directory;
  final ValueChanged<String> onFileSelected;
  final List<String>? allowedExtensions;
  final bool showHidden;

  const _FilePickerDialog({
    required this.directory,
    required this.onFileSelected,
    this.allowedExtensions,
    this.showHidden = false,
  });

  @override
  __FilePickerDialogState createState() => __FilePickerDialogState();
}

class __FilePickerDialogState extends State<_FilePickerDialog> {
  late Directory _currentDirectory;
  List<FileSystemEntity> _files = [];
  final _pathController = TextEditingController();
  final _searchController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pathController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _allowed(String path) =>
      widget.allowedExtensions == null ||
      widget.allowedExtensions!.any(
        (extension) =>
            extension.toLowerCase().replaceFirst('.', '') ==
            p.extension(path).toLowerCase().replaceFirst('.', ''),
      );

  void _openPath() {
    final path = p.normalize(
      p.absolute(
        p.isAbsolute(_pathController.text.trim())
            ? _pathController.text.trim()
            : p.join(_currentDirectory.path, _pathController.text.trim()),
      ),
    );
    if (Directory(path).existsSync()) {
      _navigateToDirectory(Directory(path));
    } else if (File(path).existsSync() && _allowed(path)) {
      widget.onFileSelected(path);
    } else {
      setState(() => _error = 'Enter an existing folder or a supported file.');
    }
  }

  @override
  void initState() {
    super.initState();
    _currentDirectory = widget.directory;
    _listFiles();
  }

  void _listFiles() {
    setState(() {
      _pathController.text = p.normalize(_currentDirectory.absolute.path);
      _error = null;
      try {
        _files = _currentDirectory.listSync().where((entity) {
          final isHidden = p.basename(entity.path).startsWith('.');

          if (!widget.showHidden && isHidden) {
            return false;
          }

          if (entity is File) {
            if (widget.allowedExtensions != null) {
              return _allowed(entity.path);
            }
          }

          return true;
        }).toList();
        _files.sort((a, b) {
          if (a is Directory && b is! Directory) {
            return -1;
          }
          if (a is! Directory && b is Directory) {
            return 1;
          }
          return p
              .basename(a.path)
              .toLowerCase()
              .compareTo(p.basename(b.path).toLowerCase());
        });
      } on FileSystemException {
        _files = [];
        _error = 'Could not read this folder. Check its permissions.';
      }
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
    final query = _searchController.text.trim().toLowerCase();
    final visible = _files
        .where((file) => p.basename(file.path).toLowerCase().contains(query))
        .toList();
    return AlertDialog(
      title: HMBColumn(
        mainAxisSize: MainAxisSize.min,
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
                          if (breadcrumb != breadcrumbs.last &&
                              breadcrumb.name != '/')
                            const Text(' / '),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          HMBTextField(
            controller: _pathController,
            labelText: 'Folder or full file path',
            suffixIcon: IconButton(
              tooltip: 'Open path',
              icon: const Icon(Icons.arrow_forward),
              onPressed: _openPath,
            ),
          ),
          HMBTextField(
            controller: _searchController,
            labelText: 'Search this folder',
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) Text(_error!),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          itemCount: visible.length,
          itemBuilder: (context, index) {
            final entity = visible[index];
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
          HMBButton(
            label: 'Up',
            hint: 'Navigate up the directory tree to the parent directory',
            onPressed: _navigateToParent,
          ),
        HMBButton(
          label: 'Cancel',
          hint: 'Close the file Picker',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}

class BreadcrumbItem {
  final String name;
  final Directory directory;

  BreadcrumbItem(this.name, this.directory);
}
