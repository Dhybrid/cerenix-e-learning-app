// lib/features/scanner/screens/document_reader_screen.dart
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:convert';

class DocumentReaderScreen extends StatefulWidget {
  final File file;
  final String fileName;

  const DocumentReaderScreen({
    super.key,
    required this.file,
    required this.fileName,
  });

  @override
  State<DocumentReaderScreen> createState() => _DocumentReaderScreenState();
}

class _DocumentReaderScreenState extends State<DocumentReaderScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  final List<TextSelection> _highlights = [];
  final List<Map<String, dynamic>> _annotations = [];
  bool _isLoading = true;
  String _documentContent = '';

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate document loading
    await Future.delayed(const Duration(seconds: 1));

    // For demo purposes, create sample content based on file type
    if (widget.fileName.toLowerCase().endsWith('.pdf')) {
      _documentContent = '''
PDF Document Content Demo

This is a sample PDF document viewer. In a real application, this would display the actual PDF content.

Document Properties:
• Title: ${widget.fileName}
• Pages: 15
• Size: ${(widget.file.lengthSync() / 1024).toStringAsFixed(2)} KB
• Created: ${DateTime.now().subtract(const Duration(days: 30))}

Chapter 1: Introduction
This chapter introduces the main concepts and provides an overview of the document content.

Chapter 2: Detailed Analysis
This section contains detailed analysis and findings from the research conducted.

Chapter 3: Conclusion
Summary of findings and recommendations for future work.

Key Points:
- Important information point 1
- Critical data point 2
- Significant finding 3
- Recommendation 4

This document reader supports highlighting, annotations, and saving your work.
''';
    } else if (widget.fileName.toLowerCase().endsWith('.doc') || 
               widget.fileName.toLowerCase().endsWith('.docx')) {
      _documentContent = '''
Word Document Content Demo

This is a sample Word document viewer. In a real application, this would display the actual Word document content.

DOCUMENT TITLE: ${widget.fileName}

SECTION 1: EXECUTIVE SUMMARY
This document provides a comprehensive analysis of the current market trends and future projections.

SECTION 2: MARKET ANALYSIS
• Current Market Size: \$500M
• Growth Rate: 15% annually
• Key Players: Company A, Company B, Company C
• Market Share Distribution

SECTION 3: TECHNICAL SPECIFICATIONS
- Platform Requirements
- System Architecture
- Integration Points
- Security Measures

SECTION 4: IMPLEMENTATION PLAN
Phase 1: Preparation (Weeks 1-2)
Phase 2: Development (Weeks 3-8)
Phase 3: Testing (Weeks 9-10)
Phase 4: Deployment (Week 11)

This document reader provides full functionality for document interaction and annotation.
''';
    } else if (widget.fileName.toLowerCase().endsWith('.xls') || 
               widget.fileName.toLowerCase().endsWith('.xlsx')) {
      _documentContent = '''
Excel Spreadsheet Demo

This is a sample Excel document viewer. In a real application, this would display the actual spreadsheet content.

SALES DATA OVERVIEW

Quarterly Performance:
Q1 2024: \$1,250,000
Q2 2024: \$1,450,000
Q3 2024: \$1,380,000
Q4 2024: \$1,620,000

Product Performance:
- Product A: 25% of total sales
- Product B: 35% of total sales
- Product C: 20% of total sales
- Product D: 20% of total sales

Regional Distribution:
- North America: 45%
- Europe: 30%
- Asia Pacific: 20%
- Other: 5%

Key Metrics:
- Gross Margin: 42%
- Operating Expenses: 28%
- Net Profit: 14%
- YoY Growth: 18%

This spreadsheet contains detailed financial data and performance metrics for comprehensive analysis.
''';
    } else {
      _documentContent = widget.file.readAsStringSync();
    }

    setState(() {
      _isLoading = false;
    });
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
            
            // Document Content
            Expanded(
              child: _isLoading 
                  ? _buildLoadingState()
                  : _buildDocumentContent(),
            ),
            
            // Toolbar
            _buildToolbar(),
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
                  widget.fileName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${(widget.file.lengthSync() / 1024).toStringAsFixed(1)} KB',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.save, color: Colors.blue),
            onPressed: _saveDocument,
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.green),
            onPressed: _shareDocument,
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
            'Loading Document...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentContent() {
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Document Title
            Text(
              widget.fileName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            
            // Document Metadata
            Text(
              'Type: ${widget.fileName.split('.').last.toUpperCase()} • '
              'Size: ${(widget.file.lengthSync() / 1024).toStringAsFixed(1)} KB',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            
            // Document Content with SelectableText for highlighting
            SelectableText(
              _documentContent,
              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Colors.black87,
              ),
              onSelectionChanged: (selection, cause) {
                if (selection.extentOffset > selection.baseOffset) {
                  _addHighlight(selection);
                }
              },
            ),
            
            // Show highlights
            if (_highlights.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Your Highlights:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              ..._highlights.map((highlight) => _buildHighlightItem(highlight)),
            ],
            
            // Show annotations
            if (_annotations.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Annotations:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              ..._annotations.map((annotation) => _buildAnnotationItem(annotation)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightItem(TextSelection highlight) {
    final text = _documentContent.substring(
      highlight.start,
      highlight.end,
    );
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.yellow.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.yellow.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
            onPressed: () => _removeHighlight(highlight),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnotationItem(Map<String, dynamic> annotation) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            annotation['text'],
            style: const TextStyle(
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            annotation['note'],
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildToolbarButton(
            icon: Icons.highlight,
            label: 'Highlight',
            onTap: _showHighlightDialog,
          ),
          _buildToolbarButton(
            icon: Icons.note_add,
            label: 'Add Note',
            onTap: _showAnnotationDialog,
          ),
          _buildToolbarButton(
            icon: Icons.bookmark,
            label: 'Bookmark',
            onTap: _addBookmark,
          ),
          _buildToolbarButton(
            icon: Icons.search,
            label: 'Search',
            onTap: _showSearchDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: Colors.blue),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _addHighlight(TextSelection selection) {
    setState(() {
      _highlights.add(selection);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Text highlighted'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _removeHighlight(TextSelection highlight) {
    setState(() {
      _highlights.remove(highlight);
    });
  }

  void _showHighlightDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Highlight'),
        content: const Text('Select text in the document to highlight it.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAnnotationDialog() {
    TextEditingController noteController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Annotation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add a note about this document:'),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                hintText: 'Enter your note...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (noteController.text.isNotEmpty) {
                _addAnnotation(noteController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _addAnnotation(String note) {
    setState(() {
      _annotations.add({
        'text': 'User Annotation',
        'note': note,
        'timestamp': DateTime.now(),
      });
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Annotation added'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _addBookmark() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bookmark added'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Document'),
        content: const Text('Search functionality would be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _saveDocument() async {
    // Save highlights and annotations
    final Map<String, dynamic> saveData = {
      'highlights': _highlights.map((h) => {
        'start': h.start,
        'end': h.end,
        'text': _documentContent.substring(h.start, h.end),
      }).toList(),
      'annotations': _annotations,
      'fileName': widget.fileName,
      'savedAt': DateTime.now().toIso8601String(),
    };

    final directory = await getApplicationDocumentsDirectory();
    final saveFile = File('${directory.path}/saved_${widget.fileName}.json');
    await saveFile.writeAsString(jsonEncode(saveData));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Document saved with annotations'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _shareDocument() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality would be implemented here'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}