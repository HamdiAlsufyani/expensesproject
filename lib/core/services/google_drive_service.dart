import 'dart:async';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../errors/app_exception.dart';

class DriveBackupFile {
  const DriveBackupFile({
    required this.id,
    required this.name,
    this.createdAt,
    this.size,
  });
  final String id;
  final String name;
  final DateTime? createdAt;
  final int? size;
}

class GoogleDriveService {
  GoogleDriveService({this.clientId, this.serverClientId});

  static const _scopes = [drive.DriveApi.driveAppdataScope];
  final String? clientId;
  final String? serverClientId;
  bool _initialized = false;
  GoogleSignInAccount? _account;

  String? get signedInEmail => _account?.email;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await GoogleSignIn.instance.initialize(
        clientId: clientId,
        serverClientId: serverClientId,
      );
      _initialized = true;
      _account = await GoogleSignIn.instance.attemptLightweightAuthentication();
    } catch (error) {
      throw DriveException('driveSetupRequired', cause: error);
    }
  }

  Future<String> signIn() async {
    try {
      await initialize();
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: _scopes,
      );
      await account.authorizationClient.authorizationHeaders(
        _scopes,
        promptIfNecessary: true,
      );
      _account = account;
      return account.email;
    } catch (error) {
      throw DriveException('googleSignInFailed', cause: error);
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
      _account = null;
    } catch (error) {
      throw DriveException('googleSignOutFailed', cause: error);
    }
  }

  Future<void> uploadBackup(File file) async {
    try {
      final api = await _driveApi(prompt: true);
      final upload = drive.Media(file.openRead(), await file.length());
      await api.files.create(
        drive.File(
          name: p.basename(file.path),
          parents: ['appDataFolder'],
          appProperties: {'backupFormat': 'sqlite', 'backupVersion': '1'},
        ),
        uploadMedia: upload,
        $fields: 'id,name,createdTime,size',
      );
    } catch (error) {
      throw DriveException('driveUploadFailed', cause: error);
    }
  }

  Future<List<DriveBackupFile>> listBackups() async {
    try {
      final api = await _driveApi();
      final list = await api.files.list(
        spaces: 'appDataFolder',
        q: "name contains 'backup_' and trashed = false",
        orderBy: 'createdTime desc',
        pageSize: 100,
        $fields: 'files(id,name,createdTime,size)',
      );
      return (list.files ?? const <drive.File>[])
          .where((file) => file.id != null && file.name != null)
          .map(
            (file) => DriveBackupFile(
              id: file.id!,
              name: file.name!,
              createdAt: file.createdTime,
              size: int.tryParse(file.size ?? ''),
            ),
          )
          .toList(growable: false);
    } catch (error) {
      throw DriveException('driveListFailed', cause: error);
    }
  }

  Future<File> downloadBackup(DriveBackupFile remote) async {
    try {
      final api = await _driveApi();
      final destinationDirectory = await getTemporaryDirectory();
      final destination = File(
        p.join(
          destinationDirectory.path,
          'download_${DateTime.now().microsecondsSinceEpoch}_${remote.name}',
        ),
      );
      final media = await api.files.get(
        remote.id,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;
      final sink = destination.openWrite();
      await media.stream.pipe(sink);
      return destination;
    } catch (error) {
      throw DriveException('driveDownloadFailed', cause: error);
    }
  }

  Future<drive.DriveApi> _driveApi({bool prompt = false}) async {
    await initialize();
    final account = _account ?? await _interactiveAccount();
    final headers = await account.authorizationClient.authorizationHeaders(
      _scopes,
      promptIfNecessary: prompt,
    );
    if (headers == null) {
      throw const DriveException('driveAuthorizationRequired');
    }
    return drive.DriveApi(_AuthorizedClient(headers));
  }

  Future<GoogleSignInAccount> _interactiveAccount() async {
    final account = await GoogleSignIn.instance.authenticate(
      scopeHint: _scopes,
    );
    _account = account;
    return account;
  }
}

class _AuthorizedClient extends http.BaseClient {
  _AuthorizedClient(this._headers);
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
