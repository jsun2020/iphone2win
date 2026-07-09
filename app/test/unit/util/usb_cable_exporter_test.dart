import 'dart:convert';
import 'dart:io';

import 'package:common/model/file_type.dart';
import 'package:localsend_app/model/cross_file.dart';
import 'package:localsend_app/util/usb/usb_cable_exporter.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('usb_cable_exporter_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  CrossFile crossFile({
    required String name,
    required FileType fileType,
    required int size,
    String? path,
    List<int>? bytes,
  }) {
    return CrossFile(
      name: name,
      fileType: fileType,
      size: size,
      thumbnail: null,
      asset: null,
      path: path,
      bytes: bytes,
      lastModified: null,
      lastAccessed: null,
    );
  }

  test('exports in-memory text bytes to outbox and preserves content', () async {
    final bytes = utf8.encode('USB clipboard text');

    final exportedPaths = await exportCrossFilesToUsbOutbox(
      outbox: tempDir,
      files: [
        crossFile(
          name: 'message.txt',
          fileType: FileType.text,
          size: bytes.length,
          bytes: bytes,
        ),
      ],
    );

    expect(exportedPaths, hasLength(1));
    expect(p.basename(exportedPaths.single), 'message.txt');
    expect(await File(exportedPaths.single).readAsString(), 'USB clipboard text');
  });

  test('copies file path into outbox without overwriting existing file', () async {
    await File(p.join(tempDir.path, 'photo.jpg')).writeAsString('existing');
    final sourceDir = await Directory.systemTemp.createTemp('usb_cable_exporter_source_');
    addTearDown(() async {
      if (await sourceDir.exists()) {
        await sourceDir.delete(recursive: true);
      }
    });
    final source = await File(p.join(sourceDir.path, 'source.jpg')).writeAsString('copied file bytes');

    final exportedPaths = await exportCrossFilesToUsbOutbox(
      outbox: tempDir,
      files: [
        crossFile(
          name: 'photo.jpg',
          fileType: FileType.image,
          size: await source.length(),
          path: source.path,
        ),
      ],
    );

    expect(exportedPaths, hasLength(1));
    expect(p.basename(exportedPaths.single), 'photo (2).jpg');
    expect(await File(p.join(tempDir.path, 'photo.jpg')).readAsString(), 'existing');
    expect(await File(exportedPaths.single).readAsString(), 'copied file bytes');
  });

  test('exports explicit text with default clipboard filename', () async {
    final exportedPath = await exportTextToUsbOutbox(
      outbox: tempDir,
      text: 'copied from clipboard',
    );

    expect(p.basename(exportedPath), 'clipboard.txt');
    expect(await File(exportedPath).readAsString(), 'copied from clipboard');
  });

  test('skips unsupported CrossFile entries with no path and no bytes', () async {
    final bytes = utf8.encode('supported');

    final exportedPaths = await exportCrossFilesToUsbOutbox(
      outbox: tempDir,
      files: [
        crossFile(
          name: 'asset-only.jpg',
          fileType: FileType.image,
          size: 123,
        ),
        crossFile(
          name: 'supported.txt',
          fileType: FileType.text,
          size: bytes.length,
          bytes: bytes,
        ),
      ],
    );

    expect(exportedPaths, hasLength(1));
    expect(p.basename(exportedPaths.single), 'supported.txt');
    expect(await File(exportedPaths.single).readAsString(), 'supported');
  });
}
