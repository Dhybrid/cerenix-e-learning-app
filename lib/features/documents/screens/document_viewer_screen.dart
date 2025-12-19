// lib/features/documents/screens/document_viewer_screen.dart
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:io';
import 'dart:convert';

// Import the shared model
import '../models/document_model.dart';
import '../services/download_service.dart';

class DocumentViewerScreen extends StatefulWidget {
  final DocumentItem document;
  final bool isOnlineViewing;

  const DocumentViewerScreen({
    super.key,
    required this.document,
    this.isOnlineViewing = false,
  });

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = true;
  String _errorMessage = '';
  dynamic _documentViewer;
  bool _isDownloading = false;
  bool _isOnlineViewing = false;

  @override
  void initState() {
    super.initState();
    _isOnlineViewing = widget.isOnlineViewing;
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final file = File(widget.document.path);
      if (await file.exists()) {
        await _loadActualDocument(file);
      } else {
        // If file doesn't exist, check if we have original URL
        if (widget.document.originalUrl != null && widget.document.originalUrl!.isNotEmpty) {
          print('📁 Local file not found, trying to download for viewing...');
          await _downloadForViewing();
        } else {
          _errorMessage = 'File not found: ${widget.document.path}';
        }
      }
    } catch (e) {
      _errorMessage = 'Error loading document: $e';
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _downloadForViewing() async {
    try {
      if (widget.document.originalUrl == null || widget.document.originalUrl!.isEmpty) {
        throw Exception('No download URL available');
      }
      
      setState(() {
        _isDownloading = true;
      });
      
      final file = await DocumentDownloadService.getPdfForViewing(
        url: widget.document.originalUrl!,
        fileName: widget.document.name,
      );
      
      if (file != null && await file.exists()) {
        await _loadActualDocument(file);
        setState(() {
          _isOnlineViewing = true;
        });
      } else {
        _errorMessage = 'Could not download document for viewing';
      }
    } catch (e) {
      _errorMessage = 'Error downloading: $e';
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<void> _loadActualDocument(File file) async {
    switch (widget.document.type) {
      case 'PDF':
        _documentViewer = PdfViewerController();
        break;
      
      case 'Text':
        final content = await file.readAsString();
        _textController.text = content;
        break;
      
      case 'Word':
        // For Word documents, we'll read as text for now
        try {
          final content = await file.readAsString();
          _textController.text = content;
        } catch (e) {
          _textController.text = 'Word document content cannot be displayed directly.\n\n'
              'File: ${widget.document.name}\n'
              'Size: ${_formatFileSize(widget.document.size)}\n'
              'Type: Word Document\n\n'
              'The actual content of this Word document cannot be displayed in this version.';
        }
        break;
      
      case 'Excel':
        await _loadExcelContent(file);
        break;
      
      default:
        // Try to read as text for unknown file types
        try {
          final content = await file.readAsString();
          _textController.text = content;
        } catch (e) {
          _textController.text = 'File content cannot be displayed.\n\n'
              'File: ${widget.document.name}\n'
              'Size: ${_formatFileSize(widget.document.size)}\n'
              'Type: ${widget.document.type}\n\n'
              'This file type is not supported for direct viewing.';
        }
    }
  }

  Future<void> _loadExcelContent(File file) async {
    try {
      // For now, show file info since Excel parsing is complex
      _textController.text = 'Excel Spreadsheet Content\n\n'
          'File: ${widget.document.name}\n'
          'Size: ${_formatFileSize(widget.document.size)}\n'
          'Type: Excel Document\n\n'
          'Excel file content cannot be displayed directly in this version.\n'
          'The actual spreadsheet data is preserved in the file.';
      
    } catch (e) {
      _textController.text = 'Excel document content cannot be displayed.\n\n'
          'File: ${widget.document.name}\n'
          'Size: ${_formatFileSize(widget.document.size)}\n'
          'Type: Excel Spreadsheet\n\n'
          'Error: $e';
    }
  }

  Future<void> _saveDocument() async {
    try {
      if (widget.document.type == 'Text') {
        final file = File(widget.document.path);
        await file.writeAsString(_textController.text);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This document type cannot be edited'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _downloadForOffline() async {
    if (widget.document.originalUrl == null || widget.document.originalUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No download URL available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    try {
      setState(() {
        _isDownloading = true;
      });
      
      final isCloudinary = widget.document.originalUrl!.contains('cloudinary.com');
      File? downloadedFile;
      
      if (isCloudinary) {
        downloadedFile = await DocumentDownloadService.downloadCloudinaryPdf(
          cloudinaryUrl: widget.document.originalUrl!,
          fileName: widget.document.name,
        );
      } else {
        downloadedFile = await DocumentDownloadService.downloadPdf(
          url: widget.document.originalUrl!,
          fileName: widget.document.name,
        );
      }
      
      if (downloadedFile != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Downloaded for offline use!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _isOnlineViewing = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to download'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Online viewing indicator
            if (_isOnlineViewing) _buildOnlineIndicator(),
            
            // Document Content
            Expanded(
              child: _isLoading 
                  ? _buildLoadingState()
                  : _errorMessage.isNotEmpty
                      ? _buildErrorState()
                      : _buildDocumentContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.document.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${widget.document.type} • ${_formatFileSize(widget.document.size)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (_canEditDocument())
            IconButton(
              icon: const Icon(Icons.save, color: Colors.blue),
              onPressed: _saveDocument,
            ),
          if (!widget.document.isStudyGuide || _isOnlineViewing)
            IconButton(
              icon: _isDownloading
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : const Icon(Icons.download, color: Colors.blue),
              onPressed: _isDownloading ? null : _downloadForOffline,
              tooltip: 'Download for offline',
            ),
        ],
      ),
    );
  }

  Widget _buildOnlineIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.shade50,
      child: Row(
        children: [
          const Icon(Icons.wifi, size: 16, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Viewing online • Tap download icon to save offline',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canEditDocument() {
    // Only allow editing text files for now
    return widget.document.type == 'Text';
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          const Text(
            'Loading Document...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          if (_isDownloading)
            const SizedBox(height: 8),
          if (_isDownloading)
            const Text(
              'Downloading for viewing...',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Error Loading Document',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.document.originalUrl != null && widget.document.originalUrl!.isNotEmpty)
                    ElevatedButton(
                      onPressed: _downloadForViewing,
                      child: const Text('Try Downloading Again'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadDocument,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentContent() {
    switch (widget.document.type) {
      case 'PDF':
        return _buildPdfViewer();
      case 'Text':
      case 'Word':
      case 'Excel':
      default:
        return _buildTextViewer();
    }
  }

  Widget _buildPdfViewer() {
    return SfPdfViewer.file(
      File(widget.document.path),
      controller: _documentViewer,
      canShowScrollHead: true,
      canShowPaginationDialog: true,
      pageLayoutMode: PdfPageLayoutMode.single,
      scrollDirection: PdfScrollDirection.vertical,
    );
  }

  Widget _buildTextViewer() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _textController,
        maxLines: null,
        expands: true,
        readOnly: !_canEditDocument(),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          hintText: _canEditDocument() 
              ? 'Start editing your document...' 
              : 'Document content (read-only)',
        ),
        style: const TextStyle(
          fontSize: 14,
          height: 1.6,
          color: Colors.black87,
          fontFamily: 'Monospace',
        ),
      ),
    );
  }

  String _formatFileSize(int size) {
    if (size < 1024) return '$size B';
    if (size < 1048576) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / 1048576).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}