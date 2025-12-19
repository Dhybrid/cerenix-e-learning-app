// lib/features/voice_chat/screens/voice_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../../../core/constants/endpoints.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class VoiceChatScreen extends StatefulWidget {
  const VoiceChatScreen({super.key});

  @override
  State<VoiceChatScreen> createState() => _VoiceChatScreenState();
}

class _VoiceChatScreenState extends State<VoiceChatScreen> {
  // State management
  late VoiceChatState _state = VoiceChatState.initializing;
  bool _showBoard = false;
  String _boardContent = '';
  String _sessionId = const Uuid().v4();
  String _conversationHistory = '';
  String _recognizedText = '';
  String _fullSessionText = '';

  // Speech services
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final ScrollController _boardScrollController = ScrollController();

  // Session management
  Timer? _silenceTimer;
  Timer? _restartTimer;
  bool _isContinuousListening = false;
  bool _userStopped = false;
  int _speechRestartCount = 0;

  // Configuration
  static const _silenceTimeout = Duration(seconds: 3); 
  static const _maxRestartAttempts = 30;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      // Initialize Hive
      if (!Hive.isBoxOpen('settings_box')) {
        await Hive.openBox('settings_box');
      }

      // Initialize speech recognition with callbacks
      bool speechAvailable = await _speech.initialize(
        onError: (error) => print('Speech error: $error'),
        onStatus: _onSpeechStatus,
      );

      if (!speechAvailable) {
        throw Exception('Speech recognition not available');
      }

      // Initialize TTS
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.7);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.1);

      // Check permissions
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        throw Exception('Microphone permission required');
      }

      // Setup TTS callbacks
      _tts.setStartHandler(() {
        if (mounted) {
          setState(() => _state = VoiceChatState.aiSpeaking);
        }
      });

      _tts.setCompletionHandler(() {
        if (mounted) {
          setState(() => _state = VoiceChatState.ready);
        }
      });

      _tts.setErrorHandler((msg) {
        print('TTS error: $msg');
        if (mounted) {
          setState(() => _state = VoiceChatState.ready);
        }
      });

      setState(() => _state = VoiceChatState.ready);
      _boardContent = 'Ready to assist you!';

      // Speak greeting
      await Future.delayed(const Duration(milliseconds: 500));
      _speakGreeting();
    } catch (e) {
      print('Initialization error: $e');
      setState(() {
        _state = VoiceChatState.error;
        _boardContent = 'Initialization failed: $e';
      });
    }
  }

  void _onSpeechStatus(String status) {
    // This handler runs when engine status changes (e.g., "listening", "notListening", etc)
    print('Speech status callback: $status');

    // If the engine stopped (notListening) unintentionally while we want continuous listening, restart it.
    if (status.toLowerCase().contains('notlistening') ||
        status.toLowerCase().contains('done') ||
        status.toLowerCase().contains('stopped')) {
      if (_isContinuousListening && !_userStopped) {
        // Attempt restart after a small delay to avoid races
        _restartSpeechRecognition();
      }
    }
  }

  void _speakGreeting() async {
    if (_state != VoiceChatState.ready) return;

    final greeting = "Hello! I'm Cerava, your learning assistant. How can I help you today?";

    setState(() {
      _boardContent = greeting;
      _conversationHistory = 'AI: $greeting\n\n';
    });

    await _speakText(greeting);
  }

  Future<void> _speakText(String text) async {
    if (_state == VoiceChatState.aiSpeaking) {
      await _tts.stop();
    }

    final cleanText = _cleanTextForTTS(text);
    if (cleanText.isEmpty) return;

    await _tts.speak(cleanText);
  }

  String _cleanTextForTTS(String text) {
    String cleaned = text;

    // Remove markdown and code blocks
    cleaned = cleaned.replaceAll(RegExp(r'```[\s\S]*?```'), 'Code example');
    cleaned = cleaned.replaceAll(RegExp(r'`([^`]+)`'), 'code');
    cleaned = cleaned.replaceAll(RegExp(r'#+\s*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\*\*|\*|__|_'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');

    // Clean up whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.trim();
  }

  void _startContinuousListening() async {
    print('=== STARTING CONTINUOUS LISTENING ===');

    if (_state == VoiceChatState.aiSpeaking) {
      await _tts.stop();
    }

    setState(() {
      _state = VoiceChatState.listening;
      _recognizedText = '';
      _fullSessionText = ''; // new session transcript
      _isContinuousListening = true;
      _userStopped = false;
      _speechRestartCount = 0;
      _boardContent = '🎤 Listening continuously...\n\nSpeak now. I will keep listening.\n\nClick red button when done.';
    });

    // Start initial recognition
    _startSpeechRecognition();
  }

  void _startSpeechRecognition() async {
    if (!_isContinuousListening || _userStopped) return;

    print('Starting speech recognition... (attempt ${_speechRestartCount + 1})');

    try {
      // Listen. We request a very long listenFor duration and set partialResults true.
      // We also rely on onStatus callback to detect 'notListening' and restart.
      await _speech.listen(
        onResult: (result) {
          // Update partial recognized text for UI
          final text = result.recognizedWords.trim();
          final isFinal = result.finalResult;

          if (text.isNotEmpty) {
            // Update partial text always
            setState(() {
              _recognizedText = text;
              // Update board with live partial
              _boardContent = '🎤 Listening...\n\nYou: $_fullSessionText ${text.trim()}\n\n● Click red button when done ●';
            });

            _scrollToBottom();
          }

          // When result becomes final, append to full session transcript
          if (isFinal && text.isNotEmpty) {
            // Append with a space, but avoid duplicate append if identical to last appended chunk
            final trimmed = text.trim();
            if (_fullSessionText.isEmpty) {
              _fullSessionText = trimmed;
            } else {
              // Avoid duplication when engine gives overlapping phrases: only append if last chunk different
              if (!_fullSessionText.endsWith(trimmed)) {
                _fullSessionText = '$_fullSessionText ' + trimmed;
              }
            }

            // clear recognizedText after final to show processing UI if needed
            setState(() {
              _recognizedText = '';
              _boardContent = '🎤 Listening...\n\nYou: $_fullSessionText\n\n● Click red button when done ●';
            });
          }

          // (Optional) reset silence timer to keep track of pauses - not used to stop listening
          _silenceTimer?.cancel();
          _silenceTimer = Timer(_silenceTimeout, () {
            print('Detected a short silence (but will continue listening).');
            // Do nothing – we intentionally continue listening.
          });
        },
        listenMode: stt.ListenMode.dictation,
        localeId: "en-US",
        cancelOnError: true,
        partialResults: true,
        // Request long segments. If underlying platform imposes max length, onStatus will detect 'notListening'
        // and our restart logic will pick up.
        listenFor: const Duration(minutes: 30),
        // pauseFor tries to control auto-pause behavior; keep reasonably long so short pauses don't stop the engine.
        // NOTE: This may be ignored by the underlying OS/platform.
        pauseFor: const Duration(seconds: 5),
      );

      print('Speech recognition started successfully');
    } catch (e) {
      print('Error starting speech recognition: $e');
      _restartSpeechRecognition();
    }
  }

  void _restartSpeechRecognition() {
    if (!_isContinuousListening || _userStopped) return;

    // 🏆 FIX: Merge the current partial result before restarting the engine.
    // This ensures no spoken words are lost when the native engine stops unexpectedly.
    if (_recognizedText.trim().isNotEmpty) {
        final lastSegment = _recognizedText.trim();
        
        if (_fullSessionText.isEmpty) {
            _fullSessionText = lastSegment;
        } else {
            // Only append if it's not already the very end of the session text
            if (!_fullSessionText.endsWith(lastSegment)) {
                _fullSessionText = '$_fullSessionText ' + lastSegment;
            }
        }
        
        _recognizedText = ''; // Clear partial text for the new segment

        // Update UI immediately after saving the last chunk
        setState(() {
            _boardContent = '🎤 Restarting...\n\nYou: $_fullSessionText\n\n● Click red button when done ●';
        });
    }

    _speechRestartCount++;

    if (_speechRestartCount > _maxRestartAttempts) {
      print('Max restart attempts reached ($_speechRestartCount). Giving up.');
      _handleListeningError();
      return;
    }

    print('Scheduling restart of speech recognition (attempt $_speechRestartCount)...');

    // Cancel any pending timers and schedule a short restart
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 300), () async {
      // Ensure the engine is stopped before trying to restart to avoid conflicts
      try {
        if (_speech.isListening) {
          await _speech.stop();
        }
      } catch (e) {
        print('Error stopping speech before restart: $e');
      }

      if (_isContinuousListening && !_userStopped) {
        _startSpeechRecognition();
      }
    });
  }

  void _stopContinuousListening() async {
    print('=== STOPPING LISTENING ===');

    _userStopped = true;
    _isContinuousListening = false;
    _silenceTimer?.cancel();
    _restartTimer?.cancel();

    try {
      // Final merge of any remaining recognized text (the fix already did this, but this is a final safeguard)
      if (_recognizedText.trim().isNotEmpty) { 
        final lastSegment = _recognizedText.trim();
        if (_fullSessionText.isEmpty) {
          _fullSessionText = lastSegment;
        } else {
           if (!_fullSessionText.endsWith(lastSegment)) {
            _fullSessionText = '$_fullSessionText ' + lastSegment;
           }
        }
        _recognizedText = '';
      }

      await _speech.stop();
      print('Speech recognition stopped');
    } catch (e) {
      print('Error stopping speech: $e');
    }

    if (_fullSessionText.trim().isEmpty) {
      print('No speech detected');
      final errorMsg = 'I could not hear anything. Please try again.';
      setState(() {
        _boardContent = errorMsg;
        _state = VoiceChatState.ready;
      });
      _speakText(errorMsg);
      return;
    }

    print('Full session text: "$_fullSessionText"');

    setState(() => _state = VoiceChatState.processing);

    // Add to conversation history
    _conversationHistory += 'You: $_fullSessionText\n';

    // Process the message
    await _processUserMessage(_fullSessionText.trim());
  }

  Future<void> _processUserMessage(String message) async {
    try {
      // Get user ID
      String? userId;
      try {
        final userBox = await Hive.openBox('user_box');
        final userData = userBox.get('current_user');
        if (userData is Map) {
          userId = userData['id']?.toString();
        }
      } catch (e) {
        print('Error getting user ID: $e');
      }

      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Send to backend
      final response = await http
          .post(
            Uri.parse(ApiEndpoints.askCerava),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'message': message,
              'session_id': _sessionId,
              'user_id': userId,
              'is_voice': true,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final reply = data['reply'] ?? "I didn't get a response.";

        setState(() {
          _boardContent = reply;
          _conversationHistory += 'AI: $reply\n\n';
          _state = VoiceChatState.aiSpeaking;
        });

        _scrollToBottom();
        await _speakText(reply);
        // After speaking we set ready in TTS completion handler.
      } else if (response.statusCode == 429) {
        final errorData = json.decode(response.body);
        final errorMsg = errorData['message'] ?? 'Daily limit reached';
        _handleError(errorMsg);
      } else {
        _handleError('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Process message error: $e');
      _handleError('Network error. Please check your connection.');
    }
  }

  void _handleListeningError() {
    final errorMsg = 'Unable to continue listening. Please try again.';
    setState(() {
      _boardContent = errorMsg;
      _state = VoiceChatState.error;
    });
    _speakText(errorMsg);
  }

  void _handleError(String errorMsg) {
    setState(() {
      _boardContent = errorMsg;
      _state = VoiceChatState.ready;
    });
    _speakText(errorMsg);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_boardScrollController.hasClients) {
        _boardScrollController.animateTo(
          _boardScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleBoard() {
    setState(() {
      _showBoard = !_showBoard;
      if (_showBoard) {
        _scrollToBottom();
      }
    });
  }

  void _resetChat() {
    _sessionId = const Uuid().v4();
    _conversationHistory = '';
    _recognizedText = '';
    _fullSessionText = '';

    _silenceTimer?.cancel();
    _restartTimer?.cancel();
    try {
      _speech.stop();
    } catch (e) {
      print('Error stopping speech during reset: $e');
    }
    _tts.stop();
    _isContinuousListening = false;
    _userStopped = true;

    setState(() {
      _state = VoiceChatState.ready;
      _boardContent = 'Ready for a new conversation!';
    });
    _speakText('New conversation started. How can I help you?');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                _buildHeader(),

                // AI Display
                Expanded(child: _buildAIDisplay()),

                // User Controls
                _buildUserControls(),
              ],
            ),

            // Floating Board Button
            if (_state != VoiceChatState.initializing)
              Positioned(
                right: 20,
                bottom: 130,
                child: _buildFloatingButton(
                  icon: Icons.preview_rounded,
                  color: const Color(0xFF6366F1),
                  onTap: _toggleBoard,
                ),
              ),

            // Lecture Board
            if (_showBoard) _buildLectureBoard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
            color: Colors.white,
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              shape: const CircleBorder(),
            ),
          ),
          const Spacer(),
          const Text(
            'Voice Assistant',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            color: Colors.white,
            onPressed: _resetChat,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIDisplay() {
    switch (_state) {
      case VoiceChatState.initializing:
        return _buildLoadingDisplay();
      case VoiceChatState.listening:
        return _buildListeningDisplay();
      case VoiceChatState.processing:
        return _buildProcessingDisplay();
      case VoiceChatState.aiSpeaking:
        return _buildAISpeakingDisplay();
      case VoiceChatState.ready:
      case VoiceChatState.error:
        return _buildReadyDisplay();
    }
  }

  Widget _buildLoadingDisplay() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFF10B981)),
          const SizedBox(height: 20),
          const Text(
            'Initializing...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildListeningDisplay() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 200,
          height: 150,
          child: Lottie.asset(
            'assets/lottie/voiceone.json',
            fit: BoxFit.contain,
            animate: true,
            repeat: true,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 200,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFEF4444).withOpacity(0.5),
                      const Color(0xFFEF4444).withOpacity(0.2),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.mic_rounded,
                  color: Color(0xFFEF4444),
                  size: 80,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '🎤 LISTENING CONTINUOUSLY',
          style: TextStyle(
            color: Color(0xFFEF4444),
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _recognizedText.isNotEmpty
                ? 'You said: "$_fullSessionText $_recognizedText"'
                : _fullSessionText.isNotEmpty
                    ? 'Session: "$_fullSessionText"'
                    : 'Speak now...',
            style: TextStyle(
              color: _recognizedText.isNotEmpty || _fullSessionText.isNotEmpty
                  ? Colors.white
                  : Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 4,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Will keep listening even when you pause',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildProcessingDisplay() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 180,
          height: 140,
          child: Lottie.asset(
            'assets/lottie/Video.json',
            fit: BoxFit.contain,
            animate: true,
            repeat: true,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 180,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF10B981).withOpacity(0.3),
                      const Color(0xFF10B981).withOpacity(0.1),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.sync_rounded,
                  color: Color(0xFF10B981),
                  size: 60,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Processing...',
          style: TextStyle(
            color: Color(0xFF10B981),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAISpeakingDisplay() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 250,
          height: 200,
          child: Lottie.asset(
            'assets/lottie/activeVoice.json',
            fit: BoxFit.contain,
            animate: true,
            repeat: true,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 250,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF10B981).withOpacity(0.3),
                      const Color(0xFF10B981).withOpacity(0.1),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.record_voice_over_rounded,
                  color: Color(0xFF10B981),
                  size: 100,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Cerava AI is Speaking...',
          style: TextStyle(
            color: Color(0xFF10B981),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildReadyDisplay() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 180,
          height: 140,
          child: Lottie.asset(
            'assets/lottie/Video.json',
            fit: BoxFit.contain,
            animate: false,
            repeat: false,
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 180,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6366F1).withOpacity(0.3),
                      const Color(0xFF6366F1).withOpacity(0.1),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.assistant_rounded,
                  color: Color(0xFF6366F1),
                  size: 60,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _state == VoiceChatState.error ? 'ERROR' : 'READY',
          style: TextStyle(
            color: _state == VoiceChatState.error
                ? const Color(0xFFEF4444)
                : const Color(0xFF10B981),
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _state == VoiceChatState.error
              ? 'Something went wrong'
              : 'Click GREEN button to start',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildUserControls() {
    return Container(
      height: 150,
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              if (_state == VoiceChatState.listening) {
                _stopContinuousListening();
              } else if (_state == VoiceChatState.ready || _state == VoiceChatState.error) {
                _startContinuousListening();
              } else if (_state == VoiceChatState.aiSpeaking) {
                // interrupt AI speaking and start listening
                _tts.stop();
                _startContinuousListening();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _getMicButtonGradient(),
                boxShadow: [
                  BoxShadow(
                    color: _getMicButtonColor().withOpacity(0.8),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                _state == VoiceChatState.listening ? Icons.stop_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _getMicButtonText(),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  LinearGradient _getMicButtonGradient() {
    switch (_state) {
      case VoiceChatState.listening:
        return const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case VoiceChatState.ready:
      case VoiceChatState.error:
        return const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  Color _getMicButtonColor() {
    switch (_state) {
      case VoiceChatState.listening:
        return const Color(0xFFEF4444);
      case VoiceChatState.ready:
      case VoiceChatState.error:
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6366F1);
    }
  }

  String _getMicButtonText() {
    switch (_state) {
      case VoiceChatState.initializing:
        return 'Initializing...';
      case VoiceChatState.listening:
        return 'CLICK TO STOP & SEND';
      case VoiceChatState.processing:
        return 'Processing...';
      case VoiceChatState.aiSpeaking:
        return 'AI Speaking - Tap to interrupt';
      case VoiceChatState.ready:
        return 'Click to START speaking';
      case VoiceChatState.error:
        return 'Try again';
    }
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildLectureBoard() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.95),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A2E),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.school_rounded, color: Color(0xFF10B981), size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Preview Panel',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 24),
                    color: Colors.white,
                    onPressed: _toggleBoard,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D2D44),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SingleChildScrollView(
                  controller: _boardScrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: MarkdownBody(
                      data: _boardContent,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: Colors.white,
                        ),
                        strong: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        em: const TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.white,
                        ),
                        code: TextStyle(
                          backgroundColor: Colors.grey[800],
                          color: Colors.white,
                          fontFamily: 'Monospace',
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _restartTimer?.cancel();
    try {
      _speech.stop();
    } catch (e) {
      // ignore
    }
    _tts.stop();
    _boardScrollController.dispose();
    super.dispose();
  }
}

enum VoiceChatState {
  initializing,
  ready,
  listening,
  processing,
  aiSpeaking,
  error,
}