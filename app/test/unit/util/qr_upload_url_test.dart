import 'dart:io';

import 'package:localsend_app/model/state/server/server_state.dart';
import 'package:localsend_app/util/qr_upload_url.dart';
import 'package:localsend_app/util/simple_server.dart';
import 'package:test/test.dart';

void main() {
  group('buildQrUploadUrl', () {
    test('returns null when server is offline', () {
      expect(
        buildQrUploadUrl(
          serverState: null,
          localIps: const ['192.168.1.7'],
        ),
        isNull,
      );
    });

    test('returns null when no local IP is available', () async {
      final serverState = await _serverState(https: false);
      addTearDown(serverState.httpServer.close);

      expect(
        buildQrUploadUrl(
          serverState: serverState,
          localIps: const [],
        ),
        isNull,
      );
    });

    test('builds an HTTP upload URL from the first local IP', () async {
      final serverState = await _serverState(port: 53317, https: false);
      addTearDown(serverState.httpServer.close);

      expect(
        buildQrUploadUrl(
          serverState: serverState,
          localIps: const ['192.168.1.7', '10.0.0.5'],
        ),
        'http://192.168.1.7:53317/upload',
      );
    });

    test('uses HTTP for QR browser upload even when the main server was HTTPS', () async {
      final serverState = await _serverState(port: 53317, https: true);
      addTearDown(serverState.httpServer.close);

      expect(
        buildQrUploadUrl(
          serverState: serverState,
          localIps: const ['192.168.1.7'],
        ),
        'http://192.168.1.7:53317/upload',
      );
    });
  });
}

Future<ServerState> _serverState({
  int port = 0,
  required bool https,
}) async {
  final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final simpleServer = SimpleServer.start(
    server: httpServer,
    routes: SimpleServerRouteBuilder(),
  );

  return ServerState(
    httpServer: simpleServer,
    alias: 'Kind Strawberry',
    port: port == 0 ? httpServer.port : port,
    https: https,
    session: null,
    webSendState: null,
    pinAttempts: const {},
  );
}
