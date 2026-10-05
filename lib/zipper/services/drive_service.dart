import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

class DriveService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveReadonlyScope],
  );

  GoogleSignInAccount? currentUser;

  Future<GoogleSignInAccount?> signIn() async {
    currentUser = await _googleSignIn.signIn();
    return currentUser;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    currentUser = null;
  }

  /// Lists files from user's Google Drive
  Future<List<drive.File>> fetchDriveFiles() async {
    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) return [];

    final driveApi = drive.DriveApi(httpClient);
    final fileList = await driveApi.files.list(
      pageSize: 20,
      $fields: "files(id, name, mimeType, size)",
    );
    return fileList.files ?? [];
  }

  /// Downloads file content as Uint8List
  Future<Uint8List> downloadFile(String fileId) async {
    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) throw Exception("Not authenticated");

    final driveApi = drive.DriveApi(httpClient);
    final drive.Media media = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    List<int> dataBytes = [];
    await for (var data in media.stream) {
      dataBytes.addAll(data);
    }
    return Uint8List.fromList(dataBytes);
  }

  /// Prompts user with a save file dialog to store processed files locally
  static Future<String?> saveFileToLocalDisk({
    required Uint8List bytes,
    required String defaultFileName,
  }) async {
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Processed File to Local Disk',
      fileName: defaultFileName,
      bytes: bytes,
    );
    return outputFile;
  }
}
