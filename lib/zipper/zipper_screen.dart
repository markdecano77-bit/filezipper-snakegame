import 'package:flutter/foundation.dart' show kIsWeb;

import 'dart:typed_data';
import 'dart:html' as html;

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import 'services/huffman_engine.dart';
import 'services/drive_service.dart';

class HuffmanZipperPage extends StatefulWidget {
  const HuffmanZipperPage({super.key});

  @override
  State<HuffmanZipperPage> createState() => _HuffmanZipperPageState();
}

class _HuffmanZipperPageState extends State<HuffmanZipperPage> {
  final DriveService _driveService = DriveService();

  String? _fileName;
  Uint8List? _fileBytes;
  Uint8List? _processedBytes;

  String _statusMessage = "Select a file or fetch from Google Drive.";
  double? _compressionRatio;
  int _processingTimeMs = 0;

  Future<void> _pickLocalFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _fileName = result.files.single.name;
        _fileBytes = result.files.single.bytes;
        _processedBytes = null;
        _compressionRatio = null;

        _statusMessage = "Loaded $_fileName (${_fileBytes!.length} bytes).";
      });
    }
  }

  Future<void> _pickFolder() async {
    try {
      // Create a folder picker
      final input = html.FileUploadInputElement()..multiple = true;

      // Allow selecting a whole folder
      input.setAttribute('webkitdirectory', 'true');

      // Open the folder picker
      input.click();

      // Wait until the user selects a folder
      await input.onChange.first;

      final files = input.files;

      if (files == null || files.isEmpty) {
        return;
      }

      // Create a ZIP archive
      final archive = Archive();

      // Get the original folder name
      String rootFolderName = 'folder';

      // Add every file from the selected folder
      for (final file in files) {
        // Get the original folder/file path
        final relativePath = file.relativePath ?? file.name;

        // Get the root folder name
        final parts = relativePath.split('/');

        if (parts.isNotEmpty && parts.first.isNotEmpty) {
          rootFolderName = parts.first;
        }

        // Read the file
        final reader = html.FileReader();

        reader.readAsArrayBuffer(file);

        await reader.onLoad.first;

        final result = reader.result;

        Uint8List bytes;

        // Convert the result into Uint8List
        if (result is ByteBuffer) {
          bytes = Uint8List.view(result);
        } else if (result is Uint8List) {
          bytes = result;
        } else if (result is List<int>) {
          bytes = Uint8List.fromList(result);
        } else {
          throw Exception(
            'Unable to read ${file.name}: unsupported byte format.',
          );
        }

        // Keep the original folder/file structure
        archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
      }

      // Convert the archive to a ZIP file
      final zipEncoder = ZipEncoder();
      final compressed = zipEncoder.encode(archive);

      // Example:
      // queen folder → queen.zip
      setState(() {
        _fileName = '$rootFolderName.zip';

        _fileBytes = Uint8List.fromList(compressed);

        _processedBytes = Uint8List.fromList(compressed);

        _compressionRatio = null;

        _statusMessage =
            'Folder "$rootFolderName" compressed successfully as '
            '$rootFolderName.zip. '
            '${files.length} files added.';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Folder Compression Error: $e';
      });
    }
  }

  Future<void> _pickFromDrive() async {
    try {
      final user = await _driveService.signIn();

      if (user == null) return;

      final files = await _driveService.fetchDriveFiles();

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF171B2E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 20),

                const Row(
                  children: [
                    Icon(Icons.cloud, color: Color(0xFF8B7CFF), size: 28),
                    SizedBox(width: 12),
                    Text(
                      "Google Drive Files",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: files.length,
                    itemBuilder: (ctx, index) {
                      final file = files[index];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6C63FF).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.insert_drive_file,
                              color: Color(0xFF8B7CFF),
                            ),
                          ),
                          title: Text(
                            file.name ?? 'Untitled',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            file.size != null
                                ? '${file.size} bytes'
                                : 'Unknown size',
                            style: const TextStyle(color: Colors.white54),
                          ),
                          onTap: () async {
                            Navigator.pop(ctx);

                            setState(() {
                              _statusMessage = "Downloading ${file.name}...";
                            });

                            final bytes = await _driveService.downloadFile(
                              file.id!,
                            );

                            setState(() {
                              _fileName = file.name;
                              _fileBytes = bytes;
                              _processedBytes = null;
                              _compressionRatio = null;

                              _statusMessage =
                                  "Downloaded ${file.name} (${bytes.length} bytes) from Google Drive.";
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _statusMessage = "Google Drive Error: $e";
      });
    }
  }

  void _compressFile() {
    if (_fileBytes == null || _fileName == null) return;

    final stopwatch = Stopwatch()..start();

    try {
      final originalName = _fileName!;

      final compressed = HuffmanEngine.compressToZip(_fileBytes!, originalName);

      stopwatch.stop();

      final zipName = originalName.toLowerCase().endsWith('.zip')
          ? originalName
          : '$originalName.zip';

      setState(() {
        _processedBytes = Uint8List.fromList(compressed);
        _fileBytes = Uint8List.fromList(compressed);
        _processingTimeMs = stopwatch.elapsedMilliseconds;

        _compressionRatio = _fileBytes!.isEmpty
            ? 0
            : ((1 - (compressed.length / _fileBytes!.length)) * 100);

        _fileName = zipName;

        _statusMessage = 'Compressed $originalName to $zipName successfully!';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Compression Error: $e';
      });
    }
  }

  Future<void> _decompressFile() async {
    if (_fileBytes == null) return;

    final stopwatch = Stopwatch()..start();

    try {
      final archive = ZipDecoder().decodeBytes(_fileBytes!);

      if (archive.isEmpty) {
        throw Exception('The ZIP file is empty.');
      }

      final file = archive.files.firstWhere((entry) => !entry.isDirectory);

      final decompressed = file.content;

      stopwatch.stop();

      if (!mounted) return;

      setState(() {
        _processedBytes = Uint8List.fromList(decompressed);
        _processingTimeMs = stopwatch.elapsedMilliseconds;
        _compressionRatio = null;
        _fileName = file.name;

        _statusMessage = 'Decompressed ${file.name} successfully!';
      });
    } catch (e) {
      stopwatch.stop();

      if (!mounted) return;

      setState(() {
        _statusMessage = 'Decompression Error: $e';
      });
    }
  }

  Future<void> _saveToDesktop() async {
    if (_processedBytes == null || _fileName == null) return;

    String defaultName = _fileName!;

    if (kIsWeb) {
      final blob = html.Blob([_processedBytes!]);

      final url = html.Url.createObjectUrlFromBlob(blob);

      html.AnchorElement(href: url)
        ..setAttribute("download", defaultName)
        ..click();

      html.Url.revokeObjectUrl(url);

      setState(() {
        _statusMessage = "Downloaded $defaultName to your Downloads folder!";
      });
    } else {
      final resultPath = await DriveService.saveFileToLocalDisk(
        bytes: _processedBytes!,
        defaultFileName: defaultName,
      );

      if (resultPath != null) {
        setState(() {
          _statusMessage = "Saved $defaultName successfully!";
        });
      }
    }
  }

  Widget _buildFileCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF171B2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF8B7CFF)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C63FF).withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.folder_zip, color: Colors.white, size: 40),
          ),

          const SizedBox(height: 18),

          Text(
            _fileName ?? "No File Selected",
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            _fileBytes != null
                ? "${_fileBytes!.length} bytes"
                : "Choose a file to begin",
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),

          const SizedBox(height: 22),

          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _actionButton(
                      icon: Icons.upload_file,
                      label: "Local File",
                      color: const Color(0xFF6C63FF),
                      onPressed: _pickLocalFile,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _actionButton(
                      icon: Icons.folder,
                      label: "Folder",
                      color: const Color(0xFF008F7A),
                      onPressed: _pickFolder,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: _actionButton(
                  icon: Icons.cloud_download,
                  label: "Google Drive",
                  color: const Color(0xFF4285F4),
                  onPressed: _pickFromDrive,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _processButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.white10,
          disabledForegroundColor: Colors.white30,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 27),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF171B2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                color: Color(0xFF8B7CFF),
                size: 24,
              ),
              SizedBox(width: 10),
              Text(
                "Result Summary",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              _statusMessage,
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),

          const SizedBox(height: 16),

          if (_fileBytes != null)
            _infoRow(
              Icons.description_outlined,
              "Original Size",
              "${_fileBytes!.length} bytes",
            ),

          if (_processedBytes != null) ...[
            const SizedBox(height: 10),

            _infoRow(
              Icons.file_copy_outlined,
              "Output Size",
              "${_processedBytes!.length} bytes",
            ),

            const SizedBox(height: 10),

            if (_compressionRatio != null)
              _infoRow(
                Icons.savings_outlined,
                "Space Saved",
                "${_compressionRatio!.toStringAsFixed(2)}%",
                valueColor: Colors.greenAccent,
              ),

            const SizedBox(height: 10),

            _infoRow(
              Icons.timer_outlined,
              "Time Taken",
              "$_processingTimeMs ms",
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveToDesktop,
                icon: const Icon(Icons.save_alt),
                label: const Text(
                  "Save Processed File",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A884),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String title,
    String value, {
    Color valueColor = Colors.white,
  }) {
    return Row(
      children: [
        Icon(icon, size: 19, color: Colors.white54),

        const SizedBox(width: 10),

        Expanded(
          child: Text(title, style: const TextStyle(color: Colors.white60)),
        ),

        Text(
          value,
          style: TextStyle(color: valueColor, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1020),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF0D1020),
        centerTitle: false,

        title: const Row(
          children: [
            Icon(Icons.folder_zip, color: Color(0xFF8B7CFF), size: 28),

            SizedBox(width: 10),

            Text(
              "Huffman Zipper",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 21,
              ),
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // HEADER
                  const Text(
                    "Compress & Decompress Files",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 7),

                  const Text(
                    "Use Huffman coding to reduce file size quickly and efficiently.",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // FILE CARD
                  _buildFileCard(),

                  const SizedBox(height: 20),

                  // PROCESS BUTTONS
                  Row(
                    children: [
                      _processButton(
                        icon: Icons.compress,
                        title: "Compress",
                        subtitle: "Create ZIP file",
                        color: const Color(0xFF6C63FF),
                        onPressed: _fileBytes != null ? _compressFile : null,
                      ),

                      const SizedBox(width: 14),

                      _processButton(
                        icon: Icons.unarchive,
                        title: "Decompress",
                        subtitle: "Extract file",
                        color: const Color(0xFF008F7A),
                        onPressed: _fileBytes != null ? _decompressFile : null,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // RESULT
                  _buildResultCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
