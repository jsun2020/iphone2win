import 'package:dart_mappable/dart_mappable.dart';
import 'package:refena_flutter/refena_flutter.dart';

part 'signaling_provider.mapper.dart';

@MappableClass()
class SignalingState with SignalingStateMappable {
  final List<String> signalingServers;
  final List<String> stunServers;

  const SignalingState({
    required this.signalingServers,
    required this.stunServers,
  });
}

final signalingProvider = ReduxProvider<SignalingService, SignalingState>((ref) {
  return SignalingService();
});

class SignalingService extends ReduxNotifier<SignalingState> {
  @override
  SignalingState init() {
    return const SignalingState(
      signalingServers: [],
      stunServers: [],
    );
  }
}

class SetupSignalingConnection extends ReduxAction<SignalingService, SignalingState> {
  @override
  SignalingState reduce() {
    return state;
  }
}
