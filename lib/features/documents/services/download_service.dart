// lib/features/documents/services/download_service.dart
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';

class DocumentDownloadService {
  static const String _downloadsBoxName = 'document_downloads';

  // Initialize Hive box for downloads
  static Future<Box> _getDownloadsBox() async {
    return await Hive.openBox(_downloadsBoxName);
  }

  // Check if PDF is already downloaded (with persistent tracking)
  static Future<bool> isPdfDownloaded(String fileName) async {
    try {
      // Check in persistent storage first (fast)
      final box = await _getDownloadsBox();
      final downloadInfo = box.get(fileName);

      if (downloadInfo != null && downloadInfo is Map) {
        // Verify file still exists
        final filePath = downloadInfo['filePath'] as String?;
        if (filePath != null) {
          final file = File(filePath);
          if (await file.exists()) {
            print('✅ Found in downloads cache: $fileName');
            return true;
          } else {
            // File deleted but still in cache - clean up
            await _removeDownloadRecord(fileName);
          }
        }
      }

      // Fallback: check filesystem
      final localPath = await getLocalPath(fileName);
      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          // File exists but not in cache - add it
          await _addDownloadRecord(
            fileName: fileName,
            filePath: localPath,
            fileSize: await file.length(),
          );
          return true;
        }
      }
      return false;
    } catch (e) {
      print('❌ Error checking if PDF is downloaded: $e');
      return false;
    }
  }

  // Get local file path for a downloaded PDF
  static Future<String?> getLocalPath(String fileName) async {
    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String filePath = '${appDocDir.path}/protected_documents/$fileName';
      return filePath;
    } catch (e) {
      print('❌ Error getting local path: $e');
      return null;
    }
  }

  // Get app's protected documents directory
  static Future<Directory> getProtectedDocumentsDirectory() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final protectedDir = Directory('${appDocDir.path}/protected_documents');

    if (!await protectedDir.exists()) {
      await protectedDir.create(recursive: true);
    }

    return protectedDir;
  }

  // Get temp directory for cached files (for streaming/viewing)
  static Future<Directory> getTempDirectory() async {
    final Directory tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/pdf_cache');

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    return cacheDir;
  }

  // Get PDF for viewing (downloads to temp if not already downloaded)
  static Future<File?> getPdfForViewing({
    required String url,
    required String fileName,
    bool forceDownload = false,
  }) async {
    try {
      print('📖 Getting PDF for viewing: $fileName');

      // Check if already downloaded in protected storage
      if (!forceDownload) {
        final isDownloaded = await isPdfDownloaded(fileName);
        if (isDownloaded) {
          final localPath = await getLocalPath(fileName);
          if (localPath != null) {
            print('✅ Using downloaded file from protected storage');
            return File(localPath);
          }
        }
      }

      // If not downloaded, get it from temp cache or download it
      final tempDir = await getTempDirectory();
      final tempFilePath = '${tempDir.path}/$fileName';
      final tempFile = File(tempFilePath);

      // Check if exists in temp cache
      if (await tempFile.exists() && !forceDownload) {
        print('📂 Using cached file from temp storage');
        return tempFile;
      }

      // Download to temp storage for viewing
      print('🌐 Downloading to temp storage for viewing...');

      // Clean up URL for better download
      String downloadUrl = url;
      if (url.contains('cloudinary.com')) {
        if (!url.contains('?')) {
          downloadUrl = '$url?fl_attachment';
        } else if (!url.contains('fl_attachment')) {
          downloadUrl = '$url&fl_attachment';
        }
      }

      final response = await http
          .get(
            Uri.parse(downloadUrl),
            headers: {
              'User-Agent': 'CerenixApp/1.0',
              'Accept': 'application/pdf, */*',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        await tempFile.writeAsBytes(response.bodyBytes);
        print('✅ Downloaded to temp storage: ${tempFile.path}');
        print('📊 Temp file size: ${tempFile.lengthSync()} bytes');
        return tempFile;
      } else {
        print('❌ Download failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error getting PDF for viewing: $e');
      return null;
    }
  }

  // Regular PDF download method (for offline use)
  static Future<File?> downloadPdf({
    required String url,
    required String fileName,
  }) async {
    try {
      print('📥 Downloading PDF for offline: $fileName');

      // Check if already downloaded (using persistent cache)
      final isDownloaded = await isPdfDownloaded(fileName);
      if (isDownloaded) {
        print('✅ File already downloaded: $fileName');
        final localPath = await getLocalPath(fileName);
        return localPath != null ? File(localPath) : null;
      }

      final protectedDir = await getProtectedDocumentsDirectory();
      final String filePath = '${protectedDir.path}/$fileName';
      final File file = File(filePath);

      // Clean up URL for better download
      String downloadUrl = url;
      if (url.contains('cloudinary.com')) {
        if (!url.contains('?')) {
          downloadUrl = '$url?fl_attachment';
        } else if (!url.contains('fl_attachment')) {
          downloadUrl = '$url&fl_attachment';
        }
      }

      print('🌐 Downloading from: $downloadUrl');

      final response = await http
          .get(
            Uri.parse(downloadUrl),
            headers: {
              'User-Agent': 'CerenixApp/1.0',
              'Accept': 'application/pdf, */*',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        final fileSize = file.lengthSync();
        print('✅ PDF downloaded successfully: ${file.path}');
        print('📊 File size: $fileSize bytes');

        // Store download info in persistent storage
        await _addDownloadRecord(
          fileName: fileName,
          filePath: filePath,
          fileSize: fileSize,
        );

        return file;
      } else {
        print('❌ Download failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error downloading PDF: $e');
      return null;
    }
  }

  // Cloudinary PDF download method (alias for backward compatibility)
  static Future<File?> downloadCloudinaryPdf({
    required String cloudinaryUrl,
    required String fileName,
  }) async {
    // Just use the regular download method with Cloudinary URL
    return await downloadPdf(url: cloudinaryUrl, fileName: fileName);
  }

  // Add download record to persistent storage
  static Future<void> _addDownloadRecord({
    required String fileName,
    required String filePath,
    required int fileSize,
  }) async {
    try {
      final box = await _getDownloadsBox();
      final downloadInfo = {
        'filePath': filePath,
        'fileSize': fileSize,
        'downloadedAt': DateTime.now().toIso8601String(),
        'lastAccessed': DateTime.now().toIso8601String(),
      };
      await box.put(fileName, downloadInfo);
      print('💾 Added download record for: $fileName');
    } catch (e) {
      print('⚠️ Error adding download record: $e');
    }
  }

  // Remove download record
  static Future<void> _removeDownloadRecord(String fileName) async {
    try {
      final box = await _getDownloadsBox();
      await box.delete(fileName);
      print('🗑️ Removed download record for: $fileName');
    } catch (e) {
      print('⚠️ Error removing download record: $e');
    }
  }

  // Delete downloaded PDF
  static Future<bool> deleteDownloadedPdf(String fileName) async {
    try {
      // Remove from persistent storage
      await _removeDownloadRecord(fileName);

      // Delete the file
      final localPath = await getLocalPath(fileName);
      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
          print('🗑️ Deleted file: $fileName');
          return true;
        }
      }
      return false;
    } catch (e) {
      print('❌ Error deleting PDF: $e');
      return false;
    }
  }

  // Get all downloaded documents (for debugging/display)
  static Future<List<Map<String, dynamic>>> getAllDownloadedDocuments() async {
    try {
      final box = await _getDownloadsBox();
      final List<Map<String, dynamic>> downloads = [];

      for (var key in box.keys) {
        if (key is String) {
          final data = box.get(key);
          if (data != null && data is Map) {
            downloads.add({
              'fileName': key,
              ...Map<String, dynamic>.from(data),
            });
          }
        }
      }

      return downloads;
    } catch (e) {
      print('❌ Error getting all downloads: $e');
      return [];
    }
  }

  // Stream PDF directly (for online viewing without downloading)
  static Future<Stream<List<int>>?> streamPdf(String url) async {
    try {
      print('🌊 Streaming PDF from: $url');

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      request.headers['User-Agent'] = 'CerenixApp/1.0';
      request.headers['Accept'] = 'application/pdf, */*';

      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode == 200) {
        print('✅ PDF streaming started');
        return streamedResponse.stream;
      } else {
        print('❌ Stream failed with status: ${streamedResponse.statusCode}');
        client.close();
        return null;
      }
    } catch (e) {
      print('❌ Error streaming PDF: $e');
      return null;
    }
  }

  // Clear temp cache (to free up space)
  static Future<void> clearTempCache() async {
    try {
      final tempDir = await getTempDirectory();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
        print('🧹 Cleared temp cache');
      }
    } catch (e) {
      print('⚠️ Error clearing temp cache: $e');
    }
  }

  // Debug method to show all downloads
  static Future<void> debugShowDownloads() async {
    try {
      final box = await _getDownloadsBox();
      print('📊 === DOWNLOADS CACHE (${box.length} items) ===');
      for (var key in box.keys) {
        final value = box.get(key);
        print('   📁 $key: $value');
      }
      print('📊 === END DOWNLOADS CACHE ===');
    } catch (e) {
      print('❌ Error showing downloads: $e');
    }
  }
}
