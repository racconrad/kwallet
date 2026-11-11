import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

abstract interface class CredentialStore {
  Future<String?> read();
  Future<void> write(String? token);
}

/// Android Keystore / Linux Secret Service. No plaintext fallback.
class SecureCredentialStore implements CredentialStore {
  const SecureCredentialStore();
  static const _channel = MethodChannel('com.knotes.app/credentials');
  // Preserve the existing Secret Service key so Linux users stay connected.
  static const _attributes = ['application', 'kwall', 'credential', 'github'];

  Future<String?> _linux(String operation, [String? token]) async {
    final process = await Process.start('secret-tool', [
      operation,
      if (operation == 'store') '--label=knotes GitHub',
      ..._attributes,
    ]);
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.drain<void>();
    if (token != null) process.stdin.write(token);
    await process.stdin.close();
    try {
      final status = await process.exitCode.timeout(
        const Duration(seconds: 30),
      );
      final value = await output;
      await errors;
      if (status == 1 && (operation == 'lookup' || operation == 'clear')) {
        return null;
      }
      if (status != 0) throw StateError('No se pudo acceder al llavero');
      return value.trim().isEmpty ? null : value.trim();
    } on TimeoutException {
      process.kill();
      throw StateError('Desbloquea el llavero e inténtalo de nuevo');
    }
  }

  @override
  Future<String?> read() async {
    if (Platform.isAndroid) return _channel.invokeMethod<String>('read');
    if (Platform.isLinux) return _linux('lookup');
    throw UnsupportedError('Almacenamiento seguro no disponible');
  }

  @override
  Future<void> write(String? token) async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('write', {'token': token});
    } else if (Platform.isLinux) {
      await _linux(token == null || token.isEmpty ? 'clear' : 'store', token);
    } else {
      throw UnsupportedError('Almacenamiento seguro no disponible');
    }
  }
}

/// Explicitly injected by tests; never used by production factories.
class MemoryCredentialStore implements CredentialStore {
  String? _token;
  @override
  Future<String?> read() async => _token;
  @override
  Future<void> write(String? token) async {
    _token = token;
  }
}
