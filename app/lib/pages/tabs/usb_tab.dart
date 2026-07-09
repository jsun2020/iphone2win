import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:localsend_app/provider/selection/selected_sending_files_provider.dart';
import 'package:localsend_app/util/file_size_helper.dart';
import 'package:localsend_app/util/native/open_folder.dart';
import 'package:localsend_app/util/native/platform_check.dart';
import 'package:localsend_app/util/usb/usb_cable_exporter.dart';
import 'package:localsend_app/util/usb/usb_cable_paths.dart';
import 'package:path/path.dart' as p;
import 'package:refena_flutter/refena_flutter.dart';

class UsbTab extends StatefulWidget {
  const UsbTab();

  @override
  State<UsbTab> createState() => _UsbTabState();
}

class _UsbTabState extends State<UsbTab> with Refena {
  bool _loading = true;
  bool _working = false;
  String? _error;
  String? _inboxPath;
  String? _outboxPath;
  List<_UsbFolderEntry> _inboxEntries = const [];
  List<_UsbFolderEntry> _outboxEntries = const [];

  bool get _busy => _loading || _working;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshUsbFolders());
  }

  Future<void> _refreshUsbFolders() async {
    if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final inbox = await getUsbInboxDirectory();
      final outbox = await getUsbOutboxDirectory();
      final inboxEntries = await _listDirectory(inbox);
      final outboxEntries = await _listDirectory(outbox);

      if (!mounted) {
        return;
      }

      setState(() {
        _inboxPath = inbox.path;
        _outboxPath = outbox.path;
        _inboxEntries = inboxEntries;
        _outboxEntries = outboxEntries;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = 'Could not load USB folders: $error';
        _loading = false;
      });
    }
  }

  Future<List<_UsbFolderEntry>> _listDirectory(Directory directory) async {
    final entries = <_UsbFolderEntry>[];

    await for (final entity in directory.list()) {
      final stat = await entity.stat();
      if (stat.type == FileSystemEntityType.notFound) {
        continue;
      }

      entries.add(
        _UsbFolderEntry(
          name: p.basename(entity.path),
          path: entity.path,
          type: stat.type,
          size: stat.type == FileSystemEntityType.file ? stat.size : null,
        ),
      );
    }

    entries.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return entries;
  }

  Future<void> _runUsbAction(Future<void> Function() action) async {
    if (_working) {
      return;
    }

    setState(() {
      _working = true;
    });

    try {
      await action();
    } catch (error) {
      _showSnackBar('USB action failed: $error');
    } finally {
      await _refreshUsbFolders();
      if (mounted) {
        setState(() {
          _working = false;
        });
      }
    }
  }

  Future<void> _openUsbFolder() async {
    await _runUsbAction(() async {
      final outbox = await getUsbOutboxDirectory();
      await openFolder(folderPath: outbox.path);
    });
  }

  Future<void> _exportSelectedFiles() async {
    await _runUsbAction(() async {
      final files = ref.read(selectedSendingFilesProvider);
      if (files.isEmpty) {
        _showSnackBar('No selected files to export.');
        return;
      }

      final outbox = await getUsbOutboxDirectory();
      final exportedPaths = await exportCrossFilesToUsbOutbox(outbox: outbox, files: files);
      if (exportedPaths.isEmpty) {
        _showSnackBar('No selected files could be exported.');
        return;
      }

      _showSnackBar('Exported ${exportedPaths.length} file(s) to USB-Outbox.');
    });
  }

  Future<void> _exportClipboardText() async {
    await _runUsbAction(() async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text;
      if (text == null || text.trim().isEmpty) {
        _showSnackBar('Clipboard text is empty.');
        return;
      }

      final outbox = await getUsbOutboxDirectory();
      await exportTextToUsbOutbox(outbox: outbox, text: text);
      _showSnackBar('Exported clipboard text to USB-Outbox.');
    });
  }

  Future<void> _clearOutbox() async {
    await _runUsbAction(() async {
      final outbox = await getUsbOutboxDirectory();
      final outboxPath = p.canonicalize(outbox.absolute.path);
      var deleted = 0;

      await for (final entity in outbox.list()) {
        final entityPath = p.canonicalize(entity.absolute.path);
        if (!p.isWithin(outboxPath, entityPath)) {
          continue;
        }

        await entity.delete(recursive: true);
        deleted++;
      }

      _showSnackBar(
        deleted == 0 ? 'USB-Outbox is already empty.' : 'Cleared $deleted item(s) from USB-Outbox.',
      );
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedFiles = context.watch(selectedSendingFilesProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      children: [
        Text(
          'USB Cable Mode',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Connect your iPhone with a USB cable, open Apple Devices on Windows, choose Files, then select iphone2win. '
          'Copy incoming files into USB-Inbox and pick up exported files from USB-Outbox.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _busy ? null : _refreshUsbFolders,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
            if (checkPlatformIsDesktop())
              OutlinedButton.icon(
                onPressed: _busy ? null : _openUsbFolder,
                icon: const Icon(Icons.folder_open),
                label: const Text('Open USB folder'),
              ),
            ElevatedButton.icon(
              onPressed: _busy ? null : _exportSelectedFiles,
              icon: const Icon(Icons.file_upload),
              label: const Text('Export selected files'),
            ),
            ElevatedButton.icon(
              onPressed: _busy ? null : _exportClipboardText,
              icon: const Icon(Icons.content_paste),
              label: const Text('Export clipboard text'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _clearOutbox,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Clear USB-Outbox'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text('Selected files from Send tab: ${selectedFiles.length}'),
        if (_loading) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 20),
        _UsbFolderSection(
          title: 'USB-Inbox',
          folderPath: _inboxPath,
          entries: _inboxEntries,
          emptyText: 'No files in USB-Inbox.',
        ),
        const SizedBox(height: 20),
        _UsbFolderSection(
          title: 'USB-Outbox',
          folderPath: _outboxPath,
          entries: _outboxEntries,
          emptyText: 'No files in USB-Outbox.',
        ),
      ],
    );
  }
}

class _UsbFolderSection extends StatelessWidget {
  final String title;
  final String? folderPath;
  final List<_UsbFolderEntry> entries;
  final String emptyText;

  const _UsbFolderSection({
    required this.title,
    required this.folderPath,
    required this.entries,
    required this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (folderPath != null) ...[
              const SizedBox(height: 4),
              SelectableText(
                folderPath!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            if (entries.isEmpty)
              Text(emptyText)
            else
              ...entries.map((entry) {
                return _UsbFolderEntryRow(entry: entry);
              }),
          ],
        ),
      ),
    );
  }
}

class _UsbFolderEntryRow extends StatelessWidget {
  final _UsbFolderEntry entry;

  const _UsbFolderEntryRow({
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = entry.size == null ? entry.path : '${entry.size!.asReadableFileSize} - ${entry.path}';

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(entry.isDirectory ? Icons.folder : Icons.insert_drive_file),
      title: Text(entry.name),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _UsbFolderEntry {
  final String name;
  final String path;
  final FileSystemEntityType type;
  final int? size;

  const _UsbFolderEntry({
    required this.name,
    required this.path,
    required this.type,
    required this.size,
  });

  bool get isDirectory => type == FileSystemEntityType.directory;
}
