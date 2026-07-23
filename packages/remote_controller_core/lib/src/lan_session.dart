// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Remote Controller contributors

import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:remote_controller_core/src/gamepad_state.dart';
import 'package:remote_controller_core/src/native_core.dart';
import 'package:remote_controller_core/src/third_party/remote_controller_core.g.dart' as native;

enum LanSessionState {
  created(0),
  running(1),
  stopped(2),
  disconnected(3),
  faulted(4),
  unknown(-1);

  const LanSessionState(this.nativeValue);

  final int nativeValue;

  static LanSessionState fromNative(int value) => values.firstWhere(
    (state) => state.nativeValue == value,
    orElse: () => unknown,
  );
}

final class LanSessionSnapshot {
  const LanSessionSnapshot({
    required this.state,
    required this.connected,
    required this.sentPacketCount,
    required this.receivedPacketCount,
    required this.droppedPacketCount,
    required this.neutralizationCount,
    required this.latestSequence,
    required this.lastInputTimestampUs,
    required this.rumbleCount,
    required this.currentState,
    required this.lowFrequencyMotor,
    required this.highFrequencyMotor,
    required this.lastError,
    required this.peerAddress,
    required this.error,
  });

  final LanSessionState state;
  final bool connected;
  final int sentPacketCount;
  final int receivedPacketCount;
  final int droppedPacketCount;
  final int neutralizationCount;
  final int latestSequence;
  final int lastInputTimestampUs;
  final int rumbleCount;
  final GamepadState currentState;
  final int lowFrequencyMotor;
  final int highFrequencyMotor;
  final int lastError;
  final String peerAddress;
  final String error;

  /// Whether the trusted-LAN handshake failed because the client presented a
  /// pairing key that did not match the server.
  bool get pairingKeyMismatch =>
      lastError == LanController.pairingKeyMismatchError;
}

abstract final class LanController {
  static const int defaultPort = 26760;
  static const int _resultOk = 0;

  /// Snapshot `lastError` value signalling a pairing-key mismatch. Mirrors the
  /// native `protocol::kPairingKeyMismatchError` sentinel ("RC" | 1).
  static const int pairingKeyMismatchError = 0x52430001;

  static LanControllerClient createClient({
    required int instanceId,
    required String serverAddress,
    int port = defaultPort,
    int pairingKey = 0,
  }) => LanControllerClient._create(instanceId, serverAddress, port, pairingKey);

  static LanControllerServer createServer({
    int port = defaultPort,
    Duration inputTimeout = const Duration(milliseconds: 100),
  }) => LanControllerServer._create(port, inputTimeout);

  /// Returns the persisted 4-digit pairing code (0..9999) a client must
  /// present, generating and persisting it on first use.
  static int pairingCode() {
    final outCode = calloc<Uint16>();
    try {
      _checkResult('rc_pairing_get_code', native.rc_pairing_get_code(outCode));
      return outCode.value;
    } finally {
      calloc.free(outCode);
    }
  }

  /// Generates and persists a fresh 4-digit pairing code, invalidating the
  /// previous one (and any client history referencing it).
  static int regeneratePairingCode() {
    final outCode = calloc<Uint16>();
    try {
      _checkResult(
        'rc_pairing_regenerate',
        native.rc_pairing_regenerate(outCode),
      );
      return outCode.value;
    } finally {
      calloc.free(outCode);
    }
  }

  static void _checkResult(String operation, int result) {
    if (result != _resultOk) {
      throw NativeCoreException(operation, result);
    }
  }

  static LanSessionSnapshot _snapshot(
    native.rc_lan_session_snapshot_v1 value,
  ) => LanSessionSnapshot(
    state: LanSessionState.fromNative(value.state),
    connected: value.connected != 0,
    sentPacketCount: value.sent_packet_count,
    receivedPacketCount: value.received_packet_count,
    droppedPacketCount: value.dropped_packet_count,
    neutralizationCount: value.neutralization_count,
    latestSequence: value.latest_sequence,
    lastInputTimestampUs: value.last_input_timestamp_us,
    rumbleCount: value.rumble_count,
    currentState: GamepadState(
      buttonFlags: value.current_state.button_flags,
      leftTrigger: value.current_state.left_trigger,
      rightTrigger: value.current_state.right_trigger,
      leftStickX: value.current_state.left_stick_x,
      leftStickY: value.current_state.left_stick_y,
      rightStickX: value.current_state.right_stick_x,
      rightStickY: value.current_state.right_stick_y,
    ),
    lowFrequencyMotor: value.low_frequency_motor,
    highFrequencyMotor: value.high_frequency_motor,
    lastError: value.last_error,
    peerAddress: _decodeChars(value.peer_address, 64),
    error: _decodeChars(value.error, 256),
  );
}

final class LanControllerClient {
  LanControllerClient._(this._handle);

  Pointer<native.rc_lan_controller_client> _handle;
  bool _closed = false;

  static LanControllerClient _create(
    int instanceId,
    String serverAddress,
    int port,
    int pairingKey,
  ) {
    final address = serverAddress.trim();
    if (address.isEmpty ||
        port <= 0 ||
        port > 65535 ||
        pairingKey < 0 ||
        pairingKey > 9999) {
      throw ArgumentError(
        'A valid server address, port and 4-digit pairing key are required.',
      );
    }
    final nativeAddress = address.toNativeUtf8();
    final outClient = calloc<Pointer<native.rc_lan_controller_client>>();
    try {
      LanController._checkResult(
        'rc_lan_client_create',
        native.rc_lan_client_create(
          instanceId,
          nativeAddress.cast(),
          port,
          pairingKey,
          outClient,
        ),
      );
      return LanControllerClient._(outClient.value);
    } finally {
      calloc.free(outClient);
      calloc.free(nativeAddress);
    }
  }

  void start() {
    _ensureOpen();
    LanController._checkResult(
      'rc_lan_client_start',
      native.rc_lan_client_start(_handle),
    );
  }

  LanSessionSnapshot snapshot() {
    _ensureOpen();
    final snapshot = calloc<native.rc_lan_session_snapshot_v1>();
    try {
      snapshot.ref.struct_size = sizeOf<native.rc_lan_session_snapshot_v1>();
      LanController._checkResult(
        'rc_lan_client_get_snapshot',
        native.rc_lan_client_get_snapshot(_handle, snapshot),
      );
      return LanController._snapshot(snapshot.ref);
    } finally {
      calloc.free(snapshot);
    }
  }

  void close() {
    if (_closed) {
      return;
    }
    native.rc_lan_client_stop(_handle);
    native.rc_lan_client_destroy(_handle);
    _handle = nullptr;
    _closed = true;
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('LanControllerClient is already closed.');
    }
  }
}

final class LanControllerServer {
  LanControllerServer._(this._handle);

  Pointer<native.rc_lan_controller_server> _handle;
  bool _closed = false;

  static LanControllerServer _create(int port, Duration inputTimeout) {
    if (port <= 0 ||
        port > 65535 ||
        inputTimeout < const Duration(milliseconds: 10) ||
        inputTimeout > const Duration(seconds: 5)) {
      throw ArgumentError('The port or input timeout is outside its range.');
    }
    final outServer = calloc<Pointer<native.rc_lan_controller_server>>();
    try {
      LanController._checkResult(
        'rc_lan_server_create',
        native.rc_lan_server_create(
          port,
          inputTimeout.inMilliseconds,
          outServer,
        ),
      );
      return LanControllerServer._(outServer.value);
    } finally {
      calloc.free(outServer);
    }
  }

  void start() {
    _ensureOpen();
    LanController._checkResult(
      'rc_lan_server_start',
      native.rc_lan_server_start(_handle),
    );
  }

  LanSessionSnapshot snapshot() {
    _ensureOpen();
    final snapshot = calloc<native.rc_lan_session_snapshot_v1>();
    try {
      snapshot.ref.struct_size = sizeOf<native.rc_lan_session_snapshot_v1>();
      LanController._checkResult(
        'rc_lan_server_get_snapshot',
        native.rc_lan_server_get_snapshot(_handle, snapshot),
      );
      return LanController._snapshot(snapshot.ref);
    } finally {
      calloc.free(snapshot);
    }
  }

  void close() {
    if (_closed) {
      return;
    }
    native.rc_lan_server_stop(_handle);
    native.rc_lan_server_destroy(_handle);
    _handle = nullptr;
    _closed = true;
  }

  void _ensureOpen() {
    if (_closed) {
      throw StateError('LanControllerServer is already closed.');
    }
  }
}

String _decodeChars(Array<Char> chars, int capacity) {
  final bytes = <int>[];
  for (var index = 0; index < capacity; ++index) {
    final value = chars[index] & 0xff;
    if (value == 0) {
      break;
    }
    bytes.add(value);
  }
  return utf8.decode(bytes, allowMalformed: true);
}
