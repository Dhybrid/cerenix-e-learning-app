// lib/features/documents/services/download_service.dart
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';

class DocumentDownloadService {
  // Check if PDF is already downloaded
  static Future<bool> isPdfDownloaded(String fileName) async {
    try {
      final localPath = await getLocalPath(fileName);
      if (localPath != null) {
        final file = File(localPath);
        return await file.exists();
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

  // Get temp directory for cached files (for streaming)
  static Future<Directory> getTempDirectory() async {
    final Directory tempDir = await getTemporaryDirectory();
    final cacheDir = Directory('${tempDir.path}/pdf_cache');
    
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    return cacheDir;
  }

  // Regular PDF download method
  static Future<File?> downloadPdf({
    required String url,
    required String fileName,
  }) async {
    try {
      print('📥 Downloading PDF: $fileName');
      
      final protectedDir = await getProtectedDocumentsDirectory();
      final String filePath = '${protectedDir.path}/$fileName';
      final File file = File(filePath);
      
      // Check if already downloaded
      if (await file.exists()) {
        print('✅ File already exists: $filePath');
        return file;
      }
      
      print('🌐 Downloading from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'CerenixApp/1.0',
        },
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        print('✅ PDF downloaded successfully: ${file.path}');
        print('📊 File size: ${file.lengthSync()} bytes');
        
        // Store download info
        await _storeDownloadInfo(fileName, filePath, file.lengthSync());
        
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

  // Cloudinary PDF download method
  static Future<File?> downloadCloudinaryPdf({
    required String cloudinaryUrl,
    required String fileName,
  }) async {
    try {
      print('☁️ Downloading PDF from Cloudinary...');
      print('📎 Cloudinary URL: $cloudinaryUrl');
      print('📁 File name: $fileName');
      
      // First, check if file already exists
      final isDownloaded = await isPdfDownloaded(fileName);
      if (isDownloaded) {
        final localPath = await getLocalPath(fileName);
        if (localPath != null) {
          print('✅ File already exists at: $localPath');
          return File(localPath);
        }
      }
      
      final protectedDir = await getProtectedDocumentsDirectory();
      final String filePath = '${protectedDir.path}/$fileName';
      final File file = File(filePath);
      
      // Clean up Cloudinary URL for better download
      String downloadUrl = cloudinaryUrl;
      
      // Add download parameters for Cloudinary
      if (cloudinaryUrl.contains('cloudinary.com')) {
        if (!cloudinaryUrl.contains('?')) {
          downloadUrl = '$cloudinaryUrl?fl_attachment';
        } else if (!cloudinaryUrl.contains('fl_attachment')) {
          downloadUrl = '$cloudinaryUrl&fl_attachment';
        }
        
        // Ensure it's treated as a raw file
        if (!cloudinaryUrl.contains('/raw/') && !cloudinaryUrl.contains('/image/')) {
          downloadUrl = downloadUrl.replaceAll('/upload/', '/raw/upload/');
        }
      }
      
      print('🌐 Downloading from: $downloadUrl');
      
      // Create HTTP client with longer timeout for large files
      final client = http.Client();
      
      try {
        final response = await client.get(
          Uri.parse(downloadUrl),
          headers: {
            'User-Agent': 'CerenixApp/1.0',
            'Accept': 'application/pdf, */*',
          },
        ).timeout(const Duration(seconds: 60));
        
        print('📥 Response status: ${response.statusCode}');
        print('📥 Content length: ${response.contentLength} bytes');
        print('📥 Content type: ${response.headers['content-type']}');
        
        if (response.statusCode == 200) {
          // Save the file
          await file.writeAsBytes(response.bodyBytes);
          
          final fileSize = file.lengthSync();
          print('✅ PDF downloaded successfully: ${file.path}');
          print('📊 File size: $fileSize bytes');
          
          // Store download info
          await _storeDownloadInfo(fileName, filePath, fileSize);
          
          return file;
        } else {
          print('❌ Download failed with status: ${response.statusCode}');
          return null;
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print('❌ Error downloading Cloudinary PDF: $e');
      
      // Try fallback: regular download method
      print('🔄 Trying fallback download method...');
      try {
        return await downloadPdf(
          url: cloudinaryUrl,
          fileName: fileName,
        );
      } catch (fallbackError) {
        print('❌ Fallback also failed: $fallbackError');
        return null;
      }
    }
  }

  // NEW: Get PDF file for viewing (downloads to temp if not already downloaded)
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
      final client = http.Client();
      
      try {
        final response = await client.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'CerenixApp/1.0',
            'Accept': 'application/pdf, */*',
          },
        ).timeout(const Duration(seconds: 30));
        
        if (response.statusCode == 200) {
          await tempFile.writeAsBytes(response.bodyBytes);
          print('✅ Downloaded to temp storage: ${tempFile.path}');
          print('📊 Temp file size: ${tempFile.lengthSync()} bytes');
          return tempFile;
        } else {
          print('❌ Download failed with status: ${response.statusCode}');
          return null;
        }
      } finally {
        client.close();
      }
    } catch (e) {
      print('❌ Error getting PDF for viewing: $e');
      return null;
    }
  }

  // NEW: Stream PDF directly (for online viewing without downloading)
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

  // Helper method to store download info
  static Future<void> _storeDownloadInfo(String fileName, String filePath, int fileSize) async {
    try {
      final box = await Hive.openBox('downloads_cache');
      final downloadInfo = {
        'fileName': fileName,
        'filePath': filePath,
        'fileSize': fileSize,
        'downloadedAt': DateTime.now().toIso8601String(),
        'lastAccessed': DateTime.now().toIso8601String(),
      };
      await box.put('pdf_${fileName.hashCode}', downloadInfo);
      print('💾 Stored download info for: $fileName');
    } catch (e) {
      print('⚠️ Error storing download info: $e');
    }
  }

  // Delete downloaded PDF
  static Future<bool> deleteDownloadedPdf(String fileName) async {
    try {
      final localPath = await getLocalPath(fileName);
      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
          print('🗑️ Deleted file: $fileName');
          
          // Remove from cache
          final box = await Hive.openBox('downloads_cache');
          await box.delete('pdf_${fileName.hashCode}');
          return true;
        }
      }
      return false;
    } catch (e) {
      print('❌ Error deleting PDF: $e');
      return false;
    }
  }

  // Get all downloaded PDFs
  static Future<List<Map<String, dynamic>>> getDownloadedPdfs() async {
    try {
      final box = await Hive.openBox('downloads_cache');
      final keys = box.keys.where((key) => key.toString().startsWith('pdf_')).toList();
      
      final List<Map<String, dynamic>> downloads = [];
      for (var key in keys) {
        final data = box.get(key);
        if (data != null && data is Map) {
          downloads.add(Map<String, dynamic>.from(data));
        }
      }
      
      return downloads;
    } catch (e) {
      print('❌ Error getting downloaded PDFs: $e');
      return [];
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
}