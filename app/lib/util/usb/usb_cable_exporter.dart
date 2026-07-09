import 'dart:convert';
import 'dart:io';

import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/util/usb/usb_file_paths.dart';

Future<List<String>> exportCrossFilesToUsbOutbox({
  required Directory outbox,
  required List<CrossFile> files,
}) async {
  final outboxDirectory = await outbox.create(recursive: true);
  final exportedPaths = <String>[];

  for (final file in files) {
    final target = await getAvailableUsbFile(outboxDirectory, file.name);
    if (file.bytes != null) {
      await target.writeAsBytes(file.bytes!);
      exportedPaths.add(target.path);
    } else if (file.path != null) {
      await File(file.path!).copy(target.path);
      exportedPaths.add(target.path);
    }
  }

  return exportedPaths;
}

Future<String> exportTextToUsbOutbox({
  required Directory outbox,
  required String text,
  String fileName = 'clipboard.txt',
}) async {
  final outboxDirectory = await outbox.create(recursive: true);
  final target = await getAvailableUsbFile(outboxDirectory, fileName);
  await target.writeAsBytes(utf8.encode(text));
  return target.path;
}
