import 'package:localsend_app/model/state/server/server_state.dart';

const qrUploadPath = '/upload';
const qrUploadScriptPath = '/upload.js';
const qrClipboardTextPath = '/api/iphone2win/v1/clipboard-text';

String? buildQrUploadUrl({
  required ServerState? serverState,
  required List<String> localIps,
}) {
  if (serverState == null || localIps.isEmpty) {
    return null;
  }

  return Uri(
    scheme: 'http',
    host: localIps.first,
    port: serverState.port,
    path: qrUploadPath,
  ).toString();
}
