// lib/utils/update_service.dart

import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool mandatory;

  UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.mandatory,
  });

  factory UpdateInfo.fromGithubRelease(
    Map<String, dynamic> json,
    String currentVersion,
  ) {
    final tag =
        (json['tag_name'] as String? ?? '').replaceFirst(RegExp(r'^v'), '');
    final assets = (json['assets'] as List?) ?? [];

    final apkAsset = assets.firstWhere(
      (a) => (a['name'] as String).toLowerCase().endsWith('.apk'),
      orElse: () => assets.isNotEmpty ? assets.first : null,
    );

    return UpdateInfo(
      currentVersion: currentVersion,
      latestVersion: tag,
      downloadUrl: apkAsset != null
          ? (apkAsset['browser_download_url'] as String? ?? '')
          : '',
      releaseNotes: (json['body'] as String? ?? '').trim(),
      mandatory: false,
    );
  }

  factory UpdateInfo.fromCustomJson(
    Map<String, dynamic> json,
    String currentVersion,
  ) {
    return UpdateInfo(
      currentVersion: currentVersion,
      latestVersion: (json['latestVersion'] as String? ?? '').trim(),
      downloadUrl: (json['downloadUrl'] as String? ?? '').trim(),
      releaseNotes: (json['releaseNotes'] as String? ?? '').trim(),
      mandatory: json['mandatory'] as bool? ?? false,
    );
  }
}

class UpdateService {
  static const String _envKey = 'UPDATE_CHECK_URL';

  static void _log(String msg) => debugPrint('[UpdateService] $msg');

  static Future<UpdateInfo?> checkForUpdates() async {
    try {
      // ── Versão atual ─────────────────────────────────────
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      _log('Versão atual (app): $currentVersion');

      // ── Consulta Gist/GitHub (em qualquer plataforma) ────
      final apiUrl = dotenv.env[_envKey];
      if (apiUrl == null || apiUrl.isEmpty) {
        _log('ERRO: $_envKey não definida no .env');
        return null;
      }

      final response = await http
          .get(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/vnd.github+json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        _log('ERRO: status ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      UpdateInfo info;

      if (data.containsKey('tag_name')) {
        info = UpdateInfo.fromGithubRelease(data, currentVersion);
      } else if (data.containsKey('latestVersion')) {
        info = UpdateInfo.fromCustomJson(data, currentVersion);
      } else {
        _log('ERRO: formato desconhecido — chaves: ${data.keys}');
        return null;
      }

      // Loga versões sempre, independente de plataforma
      _log('Versão disponível (remota): ${info.latestVersion}');
      _log('Atualização necessária: ${_isNewer(info.latestVersion, currentVersion)}');

      // ── Guard Android: só instala no Android ────────────
      if (!Platform.isAndroid) {
        _log('Plataforma não é Android — verificação logada, instalação ignorada.');
        return null;
      }

      if (info.downloadUrl.isEmpty) {
        _log('ERRO: downloadUrl vazio');
        return null;
      }

      if (_isNewer(info.latestVersion, currentVersion)) {
        _log('Nova versão detectada: $currentVersion → ${info.latestVersion}');
        return info;
      } else {
        _log('Já na versão mais recente ($currentVersion)');
        return null;
      }
    } catch (e, st) {
      _log('EXCEÇÃO: $e\n$st');
      return null;
    }
  }

  static bool _isNewer(String latest, String current) {
    try {
      List<int> parse(String v) =>
          v.split('.').map((p) => int.tryParse(p) ?? 0).toList();

      final l = parse(latest);
      final c = parse(current);

      for (int i = 0; i < 3; i++) {
        final lv = i < l.length ? l[i] : 0;
        final cv = i < c.length ? c[i] : 0;
        if (lv > cv) return true;
        if (lv < cv) return false;
      }
    } catch (e) {
      _log('ERRO ao comparar versões: $e');
    }
    return false;
  }

  static Future<String?> downloadAndInstallUpdate(
    String downloadUrl,
    void Function(double progress) onProgress,
  ) async {
    try {
      _log('Iniciando download: $downloadUrl');

      final dir = await getExternalStorageDirectory() ??
          await getTemporaryDirectory();
      final apkPath = '${dir.path}/agenda_drumvox_update.apk';

      final oldFile = File(apkPath);
      if (await oldFile.exists()) await oldFile.delete();

      final request = http.Request('GET', Uri.parse(downloadUrl));
      final streamed =
          await request.send().timeout(const Duration(seconds: 30));

      if (streamed.statusCode != 200) {
        return 'Servidor retornou status ${streamed.statusCode}.';
      }

      final total = streamed.contentLength ?? 0;
      int downloaded = 0;
      final bytes = <int>[];

      await for (final chunk in streamed.stream) {
        bytes.addAll(chunk);
        downloaded += chunk.length;
        if (total > 0) {
          onProgress(downloaded / total);
        }
      }

      if (downloaded == 0) {
        return 'Download falhou: nenhum byte recebido.';
      }

      final file = File(apkPath);
      await file.writeAsBytes(bytes, flush: true);
      onProgress(1.0);

      if (!await file.exists() || await file.length() == 0) {
        return 'Arquivo gravado está vazio. Verifique a URL de download.';
      }

      _log('APK gravado: $apkPath (${await file.length()} bytes)');

      await Future.delayed(const Duration(milliseconds: 600));

      // Verifica permissao para instalar APKs de fontes desconhecidas
      final canInstall = await Permission.requestInstallPackages.status;
      if (!canInstall.isGranted) {
        _log('Permissao REQUEST_INSTALL_PACKAGES nao concedida - solicitando...');
        await Permission.requestInstallPackages.request();
        final afterRequest = await Permission.requestInstallPackages.status;
        if (!afterRequest.isGranted) {
          return 'Permissao negada. Acesse Configuracoes > Instalar apps desconhecidos > '
              'selecione este app e habilite a permissao.';
        }
      }

      final result = await OpenFilex.open(
        apkPath,
        type: 'application/vnd.android.package-archive',
      );

      _log('OpenFilex result: ${result.type} - ${result.message}');

      if (result.type != ResultType.done) {
        return 'Nao foi possivel abrir o instalador: ${result.message}';
      }

      return null;
    } catch (e, st) {
      _log('EXCEÇÃO no download/instalação: $e\n$st');
      return 'Erro inesperado durante a atualização:\n$e';
    }
  }
}