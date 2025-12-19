// lib/features/documents/screens/document_selector_screen.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// Import the document viewer screen and shared model
import 'document_viewer_screen.dart';
import '../models/document_model.dart';

class DocumentSelectorScreen extends StatefulWidget {
  const DocumentSelectorScreen({super.key});

  @override
  State<DocumentSelectorScreen> createState() => _DocumentSelectorScreenState();
}

class _DocumentSelectorScreenState extends State<DocumentSelectorScreen> {
  final List<DocumentItem> _documents = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() {
      _isLoading = true;
    });

    // Load from local storage
    final directory = await getApplicationDocumentsDirectory();
    final documentDir = Directory('${directory.path}/documents');
    
    if (await documentDir.exists()) {
      final files = await documentDir.list().toList();
      _documents.clear(); // Clear existing documents to avoid duplication
      
      for (var file in files) {
        if (file is File) {
          final stat = await file.stat();
          _documents.add(DocumentItem(
            id: file.path,
            name: file.uri.pathSegments.last,
            path: file.path,
            size: stat.size,
            modifiedAt: stat.modified,
            type: _getFileType(file.uri.pathSegments.last),
          ));
        }
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  String _getFileType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    if (ext == 'pdf') return 'PDF';
    if (ext == 'txt') return 'Text';
    if (ext == 'doc' || ext == 'docx') return 'Word';
    if (ext == 'xls' || ext == 'xlsx') return 'Excel';
    if (ext == 'jpg' || ext == 'jpeg' || ext == 'png') return 'Image';
    return 'File';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Main Content
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
      // Floating Action Button for adding documents
      floatingActionButton: FloatingActionButton(
        onPressed: _addDocument,
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 8),
          const Text(
            'My Documents',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white, size: 24),
            onPressed: _searchDocuments,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Quick Access Section
        _buildQuickAccess(),
        
        // Documents List
        Expanded(
          child: _isLoading 
              ? _buildLoadingState()
              : _documents.isEmpty 
                  ? _buildEmptyState()
                  : _buildDocumentsList(),
        ),
      ],
    );
  }

  Widget _buildQuickAccess() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Access',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildQuickAccessItem(
                icon: Icons.folder_open,
                label: 'Import Files',
                color: Colors.blue,
                onTap: _browseFiles,
              ),
              _buildQuickAccessItem(
                icon: Icons.description,
                label: 'PDF Files',
                color: Colors.red,
                onTap: () => _browseFilesByType(['pdf']),
              ),
              _buildQuickAccessItem(
                icon: Icons.text_fields,
                label: 'Text Files',
                color: Colors.green,
                onTap: () => _browseFilesByType(['txt']),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Loading Documents...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Documents Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Import your first document by tapping the + button',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _documents.length,
      itemBuilder: (context, index) {
        final document = _documents[index];
        return _buildDocumentItem(document);
      },
    );
  }

  Widget _buildDocumentItem(DocumentItem document) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _getFileColor(document.type).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            _getFileIcon(document.type),
            color: _getFileColor(document.type),
            size: 22,
          ),
        ),
        title: Text(
          document.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${document.type} • ${_formatFileSize(document.size)} • ${_formatDate(document.modifiedAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          onSelected: (value) {
            if (value == 'open') {
              _openDocument(document);
            } else if (value == 'delete') {
              _deleteDocument(document);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'open',
              child: Row(
                children: [
                  Icon(Icons.open_in_new, size: 18),
                  SizedBox(width: 8),
                  Text('Open'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _openDocument(document),
      ),
    );
  }

  Color _getFileColor(String type) {
    switch (type) {
      case 'PDF': return Colors.red;
      case 'Word': return Colors.blue;
      case 'Text': return Colors.green;
      case 'Excel': return Colors.green;
      case 'Image': return Colors.purple;
      default: return Colors.grey;
    }
  }

  IconData _getFileIcon(String type) {
    switch (type) {
      case 'PDF': return Icons.picture_as_pdf;
      case 'Word': return Icons.description;
      case 'Text': return Icons.text_fields;
      case 'Excel': return Icons.table_chart;
      case 'Image': return Icons.image;
      default: return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int size) {
    if (size < 1024) return '$size B';
    if (size < 1048576) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / 1048576).toStringAsFixed(1)} MB';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _addDocument() async {
    await _browseFiles();
  }

  Future<void> _browseFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'doc', 'docx', 'xls', 'xlsx', 'jpg', 'jpeg', 'png'],
        allowMultiple: true,
      );

      if (result != null) {
        bool hasNewFiles = false;
        for (var file in result.files) {
          if (file.path != null) {
            final imported = await _saveDocument(File(file.path!), file.name);
            if (imported) hasNewFiles = true;
          }
        }
        if (hasNewFiles) {
          await _loadDocuments();
          _showMessage('Documents imported successfully');
        }
      }
    } catch (e) {
      _showError('Failed to import files: $e');
    }
  }

  Future<void> _browseFilesByType(List<String> extensions) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
        allowMultiple: true,
      );

      if (result != null) {
        bool hasNewFiles = false;
        for (var file in result.files) {
          if (file.path != null) {
            final imported = await _saveDocument(File(file.path!), file.name);
            if (imported) hasNewFiles = true;
          }
        }
        if (hasNewFiles) {
          await _loadDocuments();
          _showMessage('Documents imported successfully');
        }
      }
    } catch (e) {
      _showError('Failed to import files: $e');
    }
  }

  Future<bool> _saveDocument(File sourceFile, String fileName) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final documentsDir = Directory('${directory.path}/documents');
      if (!await documentsDir.exists()) {
        await documentsDir.create(recursive: true);
      }
      
      final destination = File('${documentsDir.path}/$fileName');
      
      // Check if file already exists to avoid duplication
      if (await destination.exists()) {
        // Option 1: Skip duplicate
        // return false;
        
        // Option 2: Rename with timestamp
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final newFileName = '${fileName.split('.').first}_$timestamp.${fileName.split('.').last}';
        final newDestination = File('${documentsDir.path}/$newFileName');
        await sourceFile.copy(newDestination.path);
        return true;
      } else {
        await sourceFile.copy(destination.path);
        return true;
      }
    } catch (e) {
      _showError('Failed to save document: $e');
      return false;
    }
  }

  void _openDocument(DocumentItem document) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentViewerScreen(
          document: document,
        ),
      ),
    );
  }

  Future<void> _deleteDocument(DocumentItem document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete "${document.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final file = File(document.path);
      if (await file.exists()) {
        await file.delete();
        await _loadDocuments();
        _showMessage('Document deleted');
      }
    }
  }

  void _searchDocuments() {
    _showMessage('Search feature coming soon');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
}