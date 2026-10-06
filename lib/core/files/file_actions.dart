import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// A file the user picked, ready for a multipart upload.
class PickedFile {
  const PickedFile({required this.path, required this.name});

  final String path;
  final String name;

  bool get isPdf => name.toLowerCase().endsWith('.pdf');
}

/// Bottom sheet: take a photo, choose a photo, or (when [allowPdf]) choose a
/// PDF. Returns null when cancelled.
Future<PickedFile?> pickDocumentOrPhoto(
  BuildContext context, {
  bool allowPdf = true,
}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Take a photo'),
            onTap: () => Navigator.of(c).pop('camera'),
          ),
          ListTile(
            title: const Text('Choose a photo'),
            onTap: () => Navigator.of(c).pop('gallery'),
          ),
          if (allowPdf)
            ListTile(
              title: const Text('Choose a PDF'),
              onTap: () => Navigator.of(c).pop('pdf'),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null) return null;

  if (choice == 'pdf') {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = f?.path;
    if (f == null || path == null) return null;
    return PickedFile(path: path, name: f.name);
  }
  return pickPhoto(
    source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
  );
}

/// One photo, downscaled so it stays inside the server's upload limits
/// (4 MB for avatars, 10 MB for records).
Future<PickedFile?> pickPhoto({ImageSource source = ImageSource.gallery}) async {
  final x = await ImagePicker().pickImage(
    source: source,
    maxWidth: 2000,
    maxHeight: 2000,
    imageQuality: 85,
  );
  if (x == null) return null;
  return PickedFile(path: x.path, name: x.name);
}

/// Writes authed bytes to a temp file and opens it in the system viewer
/// (PDF reader, gallery). Returns an error message, or null on success.
Future<String?> openBytesExternally(Uint8List bytes, String fileName) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    final result = await OpenFilex.open(file.path);
    return result.type == ResultType.done ? null : result.message;
  } on Exception catch (e) {
    return 'Could not open the file ($e).';
  }
}
