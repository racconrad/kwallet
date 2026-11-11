import 'dart:convert';
import 'dart:io';

/// Representa el usuario autenticado de GitHub.
class GitHubUser {
  final String login;
  final String name;
  final String avatarUrl;
  final String htmlUrl;

  const GitHubUser({
    required this.login,
    required this.name,
    required this.avatarUrl,
    required this.htmlUrl,
  });

  factory GitHubUser.fromJson(Map<String, dynamic> json) => GitHubUser(
    login: json['login'] as String? ?? '',
    name: (json['name'] as String?)?.isNotEmpty == true
        ? json['name'] as String
        : (json['login'] as String? ?? ''),
    avatarUrl: json['avatar_url'] as String? ?? '',
    htmlUrl: json['html_url'] as String? ?? '',
  );
}

/// Resultado de una sincronización a un Gist de GitHub.
class GitHubGistSyncResult {
  final String gistId;
  final String htmlUrl;
  final DateTime updatedAt;

  const GitHubGistSyncResult({
    required this.gistId,
    required this.htmlUrl,
    required this.updatedAt,
  });
}

/// Servicio en Dart puro para sincronizar respaldos de knotes con GitHub Secret Gists.
class GitHubCloudService {
  final String baseUrl;
  final HttpClient Function()? clientFactory;

  static const String backupFilename = 'knotes-backup.json';
  static const String _legacyBackupFilename = 'kwall-backup.json';
  static const String gistDescription =
      'knotes - Respaldo seguro en la nube (Gist Secreto)';

  GitHubCloudService({
    this.baseUrl = 'https://api.github.com',
    this.clientFactory,
  });

  HttpClient _createClient() =>
      clientFactory != null ? clientFactory!() : HttpClient();

  Future<Map<String, dynamic>> _request({
    required String method,
    required String path,
    required String token,
    Map<String, dynamic>? body,
  }) async {
    final client = _createClient();
    try {
      final uri = path.startsWith('http')
          ? Uri.parse(path)
          : Uri.parse('$baseUrl$path');
      if (uri.scheme != 'https' || uri.host != Uri.parse(baseUrl).host) {
        throw const FormatException('Destino no permitido');
      }
      final request = await client.openUrl(method, uri);
      request.followRedirects = false;
      request.headers.set('User-Agent', 'knotes-app');
      request.headers.set('Authorization', 'Bearer $token');
      request.headers.set('Accept', 'application/vnd.github+json');
      request.headers.set('X-GitHub-Api-Version', '2022-11-28');

      if (body != null) {
        request.headers.contentType = ContentType.json;
        final jsonBytes = utf8.encode(jsonEncode(body));
        request.headers.contentLength = jsonBytes.length;
        request.add(jsonBytes);
      }

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (responseBody.isEmpty) return {};
        final decoded = jsonDecode(responseBody);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is List) return {'data': decoded};
        return {'result': decoded};
      } else {
        String message = 'Error ${response.statusCode} de GitHub';
        try {
          final errorJson = jsonDecode(responseBody);
          if (errorJson is Map && errorJson['message'] != null) {
            message = errorJson['message'].toString();
          }
        } catch (_) {}
        throw HttpException(message, uri: uri);
      }
    } finally {
      client.close();
    }
  }

  /// Verifica el token PAT de GitHub y retorna los datos del perfil de usuario.
  Future<GitHubUser> verifyToken(String token) async {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) {
      throw const FormatException('El token no puede estar vacío.');
    }
    final response = await _request(
      method: 'GET',
      path: '/user',
      token: cleanToken,
    );
    return GitHubUser.fromJson(response);
  }

  /// Busca si el usuario ya posee un Gist secreto previo con el respaldo de knotes.
  Future<String?> findBackupGist(String token) async {
    final response = await _request(
      method: 'GET',
      path: '/gists?per_page=100',
      token: token.trim(),
    );
    final gists = response['data'] as List? ?? [];
    for (final item in gists) {
      if (item is Map) {
        final files = item['files'];
        if (files is Map &&
            (files.containsKey(backupFilename) ||
                files.containsKey(_legacyBackupFilename))) {
          return item['id'] as String?;
        }
      }
    }
    return null;
  }

  /// Sincroniza (crea o actualiza) el respaldo JSON en el Gist secreto.
  Future<GitHubGistSyncResult> syncBackup({
    required String token,
    required String backupJson,
    String? gistId,
  }) async {
    final cleanToken = token.trim();
    final cleanGistId = gistId?.trim();

    Map<String, dynamic> response;
    if (cleanGistId != null && cleanGistId.isNotEmpty) {
      // Actualiza Gist existente
      response = await _request(
        method: 'PATCH',
        path: '/gists/$cleanGistId',
        token: cleanToken,
        body: {
          'description': gistDescription,
          'files': {
            backupFilename: {'content': backupJson},
          },
        },
      );
    } else {
      // Crea un nuevo Gist Secreto (public: false)
      response = await _request(
        method: 'POST',
        path: '/gists',
        token: cleanToken,
        body: {
          'description': gistDescription,
          'public': false,
          'files': {
            backupFilename: {'content': backupJson},
          },
        },
      );
    }

    final id = response['id'] as String? ?? cleanGistId ?? '';
    final htmlUrl = response['html_url'] as String? ?? '';
    final updatedAt =
        DateTime.tryParse(response['updated_at'] as String? ?? '') ??
        DateTime.now();

    return GitHubGistSyncResult(
      gistId: id,
      htmlUrl: htmlUrl,
      updatedAt: updatedAt,
    );
  }

  /// Descarga el contenido del archivo de respaldo JSON desde el Gist.
  Future<String> fetchBackup({
    required String token,
    required String gistId,
  }) async {
    final response = await _request(
      method: 'GET',
      path: '/gists/${gistId.trim()}',
      token: token.trim(),
    );

    final files = response['files'] as Map<String, dynamic>?;
    final file =
        (files?[backupFilename] ?? files?[_legacyBackupFilename])
            as Map<String, dynamic>?;
    if (file == null) {
      throw const FormatException(
        'No se encontró el archivo knotes-backup.json en el Gist.',
      );
    }

    if (file['truncated'] == true && file['raw_url'] != null) {
      final client = _createClient();
      try {
        final rawUri = Uri.parse(file['raw_url'] as String);
        if (rawUri.scheme != 'https' ||
            rawUri.host != 'gist.githubusercontent.com') {
          throw const FormatException('Destino no permitido');
        }
        final request = await client.getUrl(rawUri);
        request.followRedirects = false;
        request.headers.set('User-Agent', 'knotes-app');
        request.headers.set('Authorization', 'Bearer ${token.trim()}');
        final rawResponse = await request.close();
        if (rawResponse.statusCode != 200) {
          throw const HttpException('No se pudo descargar el respaldo');
        }
        return await rawResponse.transform(utf8.decoder).join();
      } finally {
        client.close();
      }
    }

    final content = file['content'] as String?;
    if (content == null || content.isEmpty) {
      throw const FormatException('El respaldo en GitHub está vacío.');
    }
    return content;
  }
}
