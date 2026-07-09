import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:localsend_app/util/native/directories.dart';
import 'package:localsend_app/util/usb/usb_file_paths.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart' as path_provider;

export 'package:localsend_app/util/usb/usb_file_paths.dart';

Future<Directory> getUsbInboxDirectory() {
  return _getUsbDirectory(usbInboxFolderName);
}

Future<Directory> getUsbOutboxDirectory() {
  return _getUsbDirectory(usbOutboxFolderName);
}

Future<Directory> getUsbWindowsStagingDirectory() {
  return _getUsbDirectory(usbWindowsStagingFolderName);
}

Future<Directory> _getUsbDirectory(String folderName) async {
  final root = await _getUsbRootDirectory();
  return Directory(p.join(root.path, folderName)).create(recursive: true);
}

Future<Directory> _getUsbRootDirectory() async {
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    return path_provider.getApplicationDocumentsDirectory();
  }

  return Directory(await getDefaultDestinationDirectory());
}
