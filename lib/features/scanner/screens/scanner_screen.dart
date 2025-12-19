// lib/features/scanner/screens/new_scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:file_picker/file_picker.dart'; // Commented out PDF browsing
import 'package:open_file/open_file.dart';
import 'dart:io';

// import 'document_reader_screen.dart'; // Commented out for now

class NewScannerScreen extends StatefulWidget {
  const NewScannerScreen({super.key});

  @override
  State<NewScannerScreen> createState() => _NewScannerScreenState();
}

class _NewScannerScreenState extends State<NewScannerScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedFile;
  String? _fileName;
  String? _extractedText;
  bool _isScanning = false;
  bool _showPreview = false;

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
            'Image Scanner',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upload Section
          _buildUploadSection(),
          const SizedBox(height: 24),
          
          // Preview Section
          if (_showPreview && _selectedFile != null) _buildPreviewSection(),
          
          // Extract Button
          if (_selectedFile != null && !_showPreview) _buildExtractButton(),
          
          // Extracted Content
          if (_showPreview && _extractedText != null) _buildExtractedContent(),
        ],
      ),
    );
  }

  Widget _buildUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Upload Image',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select or take a photo to extract text',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 24),
        
        // Upload Options - Only camera options now
        Row(
          children: [
            // Commented out PDF browsing
            /*
            Expanded(
              child: _buildUploadOption(
                icon: Icons.folder_open,
                title: 'Browse Files',
                subtitle: 'PDF, DOC, TXT',
                color: Colors.blue,
                onTap: _pickDocument,
              ),
            ),
            const SizedBox(width: 16),
            */
            Expanded(
              child: _buildUploadOption(
                icon: Icons.camera_alt,
                title: 'Take Photo',
                subtitle: 'Capture document',
                color: Colors.green,
                onTap: _showImageSourceDialog,
              ),
            ),
          ],
        ),
        
        // Selected File Info
        if (_selectedFile != null && !_showPreview) _buildSelectedFileInfo(),
      ],
    );
  }

  Widget _buildUploadOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFileInfo() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade600, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fileName ?? 'Image',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Ready for text extraction',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.visibility, color: Colors.blue.shade600),
            onPressed: _openFilePreview,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection() {
    final isImage = _fileName?.toLowerCase().endsWith('.jpg') ?? 
                    _fileName?.toLowerCase().endsWith('.jpeg') ?? 
                    _fileName?.toLowerCase().endsWith('.png') ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Image Preview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: 300,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: _selectedFile != null 
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      // Show actual image if it's an image file
                      if (isImage && _selectedFile != null)
                        Image.file(
                          _selectedFile!,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildFallbackPreview();
                          },
                        )
                      else
                        _buildFallbackPreview(),
                      
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 20),
                            onPressed: () {
                              setState(() {
                                _showPreview = false;
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : const Center(
                  child: Text('No image selected'),
                ),
        ),
        const SizedBox(height: 12),
        Text(
          _fileName ?? 'Selected Image',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFallbackPreview() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo,
            size: 50,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 8),
          Text(
            _fileName ?? 'Image Preview',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Preview not available',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtractButton() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _startTextExtraction,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isScanning
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Extracting Text...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Extract Text with AI',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildExtractedContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Text(
          'Extracted Content',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              Text(
                _extractedText ?? 'No content extracted',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              // Only Ask AI button now
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showAIAssistant,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Ask AI Assistant',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Commented out PDF document picking
  /*
  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _fileName = result.files.single.name;
          _showPreview = false;
        });
      }
    } catch (e) {
      _showError('Failed to pick document: $e');
    }
  }
  */

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.green),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImageFromGallery();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedFile = File(image.path);
          _fileName = 'Camera_${DateTime.now().millisecondsSinceEpoch}.jpg';
          _showPreview = false;
        });
      }
    } catch (e) {
      _showError('Failed to capture image: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedFile = File(image.path);
          _fileName = 'Gallery_${DateTime.now().millisecondsSinceEpoch}.jpg';
          _showPreview = false;
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _openFile() async {
    if (_selectedFile != null) {
      await OpenFile.open(_selectedFile!.path);
    }
  }

  void _openFilePreview() {
    setState(() {
      _showPreview = true;
    });
  }

  void _startTextExtraction() async {
    if (_selectedFile == null) return;

    setState(() {
      _isScanning = true;
    });

    // Simulate AI text extraction process
    await Future.delayed(const Duration(seconds: 2));

    setState(() {
      _isScanning = false;
      _showPreview = true;
      _extractedText = '''
DEMO EXTRACTED TEXT CONTENT

This is a demonstration of the AI text extraction feature. In a real application, this would contain the actual text content extracted from your image.

Image Information:
• File Name: ${_fileName ?? 'Unknown'}
• File Type: ${_fileName?.split('.').last.toUpperCase() ?? 'Image'}
• Extraction Method: AI-Powered OCR
• Confidence Score: 94%

Sample Extracted Content:
"The future of document processing lies in artificial intelligence and machine learning technologies. These advanced systems can understand context, recognize patterns, and extract meaningful information from various image formats including photos, scanned documents, and screenshots.

Key benefits include:
- Improved accuracy in text recognition from images
- Faster processing times
- Better context understanding
- Multi-format image support

This technology is transforming how businesses handle document management and data extraction from visual content."

The AI has successfully processed your image and is ready for further analysis or conversation.
''';
    });
  }

  void _showAIAssistant() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'AI Assistant',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_awesome, size: 50, color: Colors.blue),
                    const SizedBox(height: 16),
                    const Text(
                      'AI Assistant Feature',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This would open an AI chat interface where you can ask questions about the extracted text content from your image.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Commented out document reader navigation
  /*
  void _openInDocumentReader() {
    if (_selectedFile != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentReaderScreen(
            file: _selectedFile!,
            fileName: _fileName!,
          ),
        ),
      );
    }
  }
  */

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}