// lib/features/voice_chat/screens/ai_board_screen.dart
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
import 'package:flutter_math_fork/flutter_math.dart';

// Ensure you have a markdown plugin that supports LaTeX rendering
// or inform the user that basic markdown (like **bold**) will be supported.
// For example, using flutter_markdown_latex would be necessary for full formula support.

class AIBoardScreen extends StatefulWidget {
  const AIBoardScreen({super.key});

  @override
  State<AIBoardScreen> createState() => _AIBoardScreenState();
}

class _AIBoardScreenState extends State<AIBoardScreen> {
  // State management
  late VoiceChatState _state = VoiceChatState.initializing;
  String _panelContent = '';
  String _sessionId = const Uuid().v4();
  String _conversationHistory = '';
  String _recognizedText = '';
  String _fullSessionText = '';
  String _latestAiReply = '';
  String _currentSpokenText = '';
  String _activeSpeechChunk = '';
  bool _isPlayingLongResponse = false;
  bool _ttsConfigured = false;

  // Speech services
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final ScrollController _panelScrollController = ScrollController();

  // Session management
  Timer? _silenceTimer;
  Timer? _restartTimer;
  bool _isContinuousListening = false;
  bool _userStopped = false;
  int _speechRestartCount = 0;

  // Configuration
  static const _silenceTimeout = Duration(seconds: 3);
  static const _maxRestartAttempts = 30;
  static const _ttsChunkLength = 360;

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

      // Check permissions
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        throw Exception('Microphone permission required');
      }

      await _warmUpSpeechRecognition();
      await _configureTts();

      // Setup TTS callbacks
      _tts.setStartHandler(() {
        if (mounted) {
          setState(() => _state = VoiceChatState.aiSpeaking);
        }
      });

      _tts.setCompletionHandler(() {});

      _tts.setErrorHandler((msg) {
        print('TTS error: $msg');
        if (mounted) {
          setState(() => _state = VoiceChatState.ready);
        }
      });

      setState(() => _state = VoiceChatState.ready);
      _panelContent = 'Ready to assist you!';

      // Speak greeting
      await Future.delayed(const Duration(milliseconds: 500));
      _speakGreeting();
    } catch (e) {
      print('Initialization error: $e');
      setState(() {
        _state = VoiceChatState.error;
        _panelContent = 'Initialization failed: $e';
      });
    }
  }

  Future<void> _configureTts() async {
    if (_ttsConfigured) return;

    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.42);
    await _tts.setVolume(1.0);
    await _tts.setPitch(0.96);

    _tts.setProgressHandler((text, start, end, word) {
      if (!mounted || _activeSpeechChunk.isEmpty) return;

      final safeStart = start.clamp(0, _activeSpeechChunk.length);
      final safeEnd = end.clamp(safeStart, _activeSpeechChunk.length);
      final currentSlice = _activeSpeechChunk.substring(safeStart, safeEnd).trim();

      if (currentSlice.isNotEmpty) {
        setState(() {
          _currentSpokenText = currentSlice;
        });
      }
    });

    _ttsConfigured = true;
  }

  Future<void> _warmUpSpeechRecognition() async {
    try {
      await _speech.listen(
        onResult: (_) {},
        listenMode: stt.ListenMode.dictation,
        localeId: 'en-US',
        cancelOnError: false,
        partialResults: false,
        listenFor: const Duration(milliseconds: 600),
        pauseFor: const Duration(milliseconds: 600),
      );
      await Future.delayed(const Duration(milliseconds: 150));
    } catch (_) {
      // Ignore warmup issues and continue with normal initialization.
    } finally {
      try {
        await _speech.stop();
      } catch (_) {
        // Ignore cleanup issues during warmup.
      }
    }
  }

  void _onSpeechStatus(String status) {
    print('Speech status callback: $status');

    if (status.toLowerCase().contains('notlistening') ||
        status.toLowerCase().contains('done') ||
        status.toLowerCase().contains('stopped')) {
      if (_isContinuousListening && !_userStopped) {
        _restartSpeechRecognition();
      }
    }
  }

  void _speakGreeting() async {
    if (_state != VoiceChatState.ready) return;

    final greeting = "Hello! I'm Cerava, your learning assistant. How can I help you today?";

    setState(() {
      _panelContent = greeting;
      _conversationHistory = 'AI: $greeting\n\n';
      _latestAiReply = greeting;
      _currentSpokenText = greeting;
    });

    _scrollToBottom();
    await _speakText(greeting);
  }

  Future<void> _speakText(String text) async {
    await _configureTts();

    if (text.isEmpty) return;
    
    // Stop any currently speaking text immediately
    if (_state == VoiceChatState.aiSpeaking) {
      await _tts.stop();
    }

    final cleanText = _cleanTextForTTS(text);
    if (cleanText.isEmpty) {
       if (mounted) {
         setState(() => _state = VoiceChatState.ready);
       }
       return;
    }

    if (mounted) {
      setState(() {
        _latestAiReply = text;
      });
    }

    await _speakLongText(cleanText);
  }

  // UPDATED: Robust splitting logic
  Future<void> _speakLongText(String text) async {
    final RegExp sentenceSplitter = RegExp(r'(?<=[.!?])\s+(?=[A-Z0-9]|\s|$)');
    List<String> rawChunks = text.split(sentenceSplitter);
    
    List<String> finalChunks = [];
    String currentChunk = '';

    for (String chunk in rawChunks) {
      final trimmedChunk = chunk.trim();
      if (trimmedChunk.isEmpty) continue;

      if ((currentChunk.length + trimmedChunk.length + 1) > _ttsChunkLength) {
        if (currentChunk.isNotEmpty) {
          finalChunks.add(currentChunk.trim());
        }
        currentChunk = trimmedChunk;
      } else {
        currentChunk = (currentChunk.isEmpty ? trimmedChunk : '$currentChunk $trimmedChunk');
      }
    }

    if (currentChunk.isNotEmpty) {
      finalChunks.add(currentChunk.trim());
    }

    _isPlayingLongResponse = true;

    for (String chunk in finalChunks) {
      if (chunk.isEmpty) continue;

      _activeSpeechChunk = chunk;
      if (mounted) {
        setState(() {
          _state = VoiceChatState.aiSpeaking;
          _currentSpokenText = chunk;
        });
      }

      try {
        await _tts.speak(chunk);
        await Future.delayed(const Duration(milliseconds: 60));
      } catch (e) {
        print('TTS error for chunk: $e');
        if (mounted) {
          setState(() => _state = VoiceChatState.ready);
        }
        break;
      }
    }

    _activeSpeechChunk = '';
    _isPlayingLongResponse = false;

    if (mounted &&
        _state != VoiceChatState.listening &&
        _state != VoiceChatState.processing) {
      setState(() => _state = VoiceChatState.ready);
    }
  }

  // UPDATED: Removed the hard text length limit
  String _cleanTextForTTS(String text) {
    String cleaned = text;
    cleaned = cleaned.replaceAll(RegExp(r'```[\s\S]*?```'), ' Here is a code example. ');
    cleaned = cleaned.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]+\)'), ' The illustration is shown on your screen. ');
    cleaned = cleaned.replaceAll(RegExp(r'<img[^>]*>', caseSensitive: false), ' The illustration is shown on your screen. ');
    cleaned = cleaned.replaceAll(RegExp(r'`([^`]+)`'), ' code ');
    cleaned = cleaned.replaceAll(RegExp(r'\$\$[\s\S]*?\$\$'), ' The formula is shown on your screen. ');
    cleaned = cleaned.replaceAll(RegExp(r'#+\s*'), '');
    cleaned = cleaned.replaceAll(RegExp(r'\*\*|\*|__|_'), ''); 
    cleaned = cleaned.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'\$[^$]*?\$'), ' The formula is shown on your screen. '); 
    cleaned = cleaned.replaceAll(RegExp(r'\\\((.*?)\\\)'), ' The formula is shown on your screen. ');
    cleaned = cleaned.replaceAll(RegExp(r'\\\[(.*?)\\\]'), ' The formula is shown on your screen. ');
    cleaned = cleaned.replaceAll(RegExp(r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}]', unicode: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'[\u{2600}-\u{27BF}]', unicode: true), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'[|•●■◆★☆◦▪▶►]+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'[{}<>]+'), ' ');
    cleaned = cleaned.replaceAll(
      RegExp(
        r'\b(?:diagram|illustration|figure|image|chart|graph)\b\s*:?',
        caseSensitive: false,
      ),
      ' visual ',
    );
    cleaned = cleaned.replaceAll(RegExp(r'^\s*[*-]\s+', multiLine: true), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\n{2,}'), '. ');
    cleaned = cleaned.replaceAll('\n', ' ');
    cleaned = cleaned.replaceAll(';', '. ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    return cleaned.trim();
  }

  void _ensureListeningStaysAlive() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 4), () {
      if (!_isContinuousListening || _userStopped || _state != VoiceChatState.listening) {
        return;
      }

      if (!_speech.isListening) {
        _restartSpeechRecognition();
      }
    });
  }

  void _startContinuousListening() async {
    print('=== STARTING CONTINUOUS LISTENING ===');

    if (_state == VoiceChatState.aiSpeaking) {
      await _tts.stop();
    }

    setState(() {
      _state = VoiceChatState.listening;
      _recognizedText = '';
      _fullSessionText = '';
      _isContinuousListening = true;
      _userStopped = false;
      _speechRestartCount = 0;
      // Show user is listening with user's speech
      _panelContent = '🎤 Listening continuously...\n\nSpeak now. I will keep listening.\n\nClick red button when done.';
      _currentSpokenText = '';
    });

    _scrollToBottom();
    _startSpeechRecognition();
  }

  void _startSpeechRecognition() async {
    if (!_isContinuousListening || _userStopped) return;

    print('Starting speech recognition... (attempt ${_speechRestartCount + 1})');

    try {
      if (_speech.isListening) {
        await _speech.stop();
      }

      await _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords.trim();
          final isFinal = result.finalResult;

          if (text.isNotEmpty) {
            setState(() {
              _recognizedText = text;
              // Show user's speech in real-time
              _panelContent = '🎤 **Listening...**\n\n**You said:** $text';
            });
          }

          if (isFinal && text.isNotEmpty) {
            final trimmed = text.trim();
            if (_fullSessionText.isEmpty) {
              _fullSessionText = trimmed;
            } else {
              if (!_fullSessionText.endsWith(trimmed)) {
                _fullSessionText = '$_fullSessionText ' + trimmed;
              }
            }

            setState(() {
              _recognizedText = '';
            });
          }

          _ensureListeningStaysAlive();
        },
        listenMode: stt.ListenMode.dictation,
        localeId: "en-US",
        cancelOnError: false,
        partialResults: true,
        listenFor: const Duration(minutes: 30),
        pauseFor: const Duration(seconds: 30),
      );

      _speechRestartCount = 0;
      print('Speech recognition started successfully');
    } catch (e) {
      print('Error starting speech recognition: $e');
      _restartSpeechRecognition();
    }
  }

  void _restartSpeechRecognition() {
    if (!_isContinuousListening || _userStopped) return;

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

    _speechRestartCount++;

    if (_speechRestartCount > _maxRestartAttempts) {
      print('Max restart attempts reached ($_speechRestartCount). Giving up.');
      _handleListeningError();
      return;
    }

    print('Scheduling restart of speech recognition (attempt $_speechRestartCount)...');

    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 120), () async {
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
        _panelContent = errorMsg;
        _state = VoiceChatState.ready;
      });
      _scrollToBottom();
      _speakText(errorMsg);
      return;
    }

    print('Full session text: "$_fullSessionText"');

    setState(() {
      _panelContent = 'Processing your request...';
      _state = VoiceChatState.processing;
    });
    _scrollToBottom();

    _conversationHistory += 'You: $_fullSessionText\n';

    await _processUserMessage(_fullSessionText.trim());
  }

  Future<void> _processUserMessage(String message) async {
    try {
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

        // Show AI response in panel (clean emojis)
        final cleanReply = _removeEmojis(reply);
        setState(() {
          _panelContent = cleanReply;
          _conversationHistory += 'AI: $reply\n\n';
          _latestAiReply = cleanReply;
          _currentSpokenText = cleanReply;
          _state = VoiceChatState.aiSpeaking; // Set state before speaking starts
        });

        _scrollToBottom();
        // The _speakText function now handles the chunking for long replies
        await _speakText(reply); 
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

  String _removeEmojis(String text) {
    // Simple emoji removal - avoids complex regex
    String cleaned = text;
    // Remove emoji-like characters
    cleaned = cleaned.replaceAll(RegExp(r'[\u{1F600}-\u{1F64F}]', unicode: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'[\u{1F300}-\u{1F5FF}]', unicode: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'[\u{1F680}-\u{1F6FF}]', unicode: true), '');
    cleaned = cleaned.replaceAll(RegExp(r'[\u{1F1E0}-\u{1F1FF}]', unicode: true), '');
    return cleaned.trim();
  }

  void _handleListeningError() {
    final errorMsg = 'Unable to continue listening. Please try again.';
    setState(() {
      _panelContent = errorMsg;
      _state = VoiceChatState.error;
    });
    _scrollToBottom();
    _speakText(errorMsg);
  }

  void _handleError(String errorMsg) {
    setState(() {
      _panelContent = errorMsg;
      _state = VoiceChatState.ready;
    });
    _scrollToBottom();
    _speakText(errorMsg);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_panelScrollController.hasClients) {
        _panelScrollController.animateTo(
          _panelScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
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
      _panelContent = 'Ready for a new conversation!';
      _latestAiReply = '';
      _currentSpokenText = '';
    });
    _scrollToBottom();
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
                Padding(
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
                        'AI Learning Board',
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
                ),

                // Compact teaching header
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1D4ED8), Color(0xFF0F766E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.draw_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cereva Teaching Board',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _getPanelSubtitle(),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                _buildBoardInsightStrip(),

                // Panel
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF111827), Color(0xFF172033)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: SingleChildScrollView(
                            controller: _panelScrollController,
                            physics: const BouncingScrollPhysics(),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: _buildLessonContent(_getVisibleBoardText()),
                            ),
                          ),
                        ),
                        Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(vertical: 16),
                          color: Colors.white.withOpacity(0.08),
                        ),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: _buildConceptMapPanel(
                              _extractBoardKeywords(_getVisibleBoardText()),
                              title: 'Concept Flow',
                              subtitle:
                                  'A lightweight visual map of the live explanation.',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Animation and Mic Section - Simplified layout
                Container(
                  height: 130, // Fixed height to prevent overflow
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Animation Section
                      SizedBox(
                        height: 30,
                        child: _buildAnimationDisplay(),
                      ),
                      
                      // Mic Button Section - Compact layout
                      Column(
                        children: [
                          AbsorbPointer(
                            absorbing: !_canInteractWithMic(),
                            child: Opacity(
                              opacity: _canInteractWithMic() ? 1 : 0.45,
                              child: GestureDetector(
                                onTap: () {
                                  if (_state == VoiceChatState.listening) {
                                    _stopContinuousListening();
                                  } else if (_state == VoiceChatState.ready || _state == VoiceChatState.error) {
                                    _startContinuousListening();
                                  } else if (_state == VoiceChatState.aiSpeaking) {
                                    _tts.stop();
                                    _startContinuousListening();
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: _getMicButtonGradient(),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _getMicButtonColor().withOpacity(0.8),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    _state == VoiceChatState.listening ? Icons.stop_rounded : Icons.mic_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 6),
                          
                          Text(
                            _getMicButtonText(),
                            style: TextStyle(
                              color: _state == VoiceChatState.listening 
                                ? const Color(0xFFEF4444) 
                                : Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimationDisplay() {
    switch (_state) {
      case VoiceChatState.listening:
        return SizedBox(
          width: 70,
          height: 24,
          child: Lottie.asset(
            'assets/lottie/voiceone.json',
            fit: BoxFit.contain,
            animate: true,
            repeat: true,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.mic_rounded,
                color: Color(0xFFEF4444),
                size: 20,
              );
            },
          ),
        );
      case VoiceChatState.processing:
        return SizedBox(
          width: 60,
          height: 24,
          child: Lottie.asset(
            'assets/lottie/Video.json',
            fit: BoxFit.contain,
            animate: true,
            repeat: true,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.sync_rounded,
                color: Color(0xFF10B981),
                size: 20,
              );
            },
          ),
        );
      case VoiceChatState.aiSpeaking:
        return SizedBox(
          width: 90,
          height: 24,
          child: Lottie.asset(
            'assets/lottie/activeVoice.json',
            fit: BoxFit.contain,
            animate: true,
            repeat: true,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.record_voice_over_rounded,
                color: Color(0xFF10B981),
                size: 20,
              );
            },
          ),
        );
      case VoiceChatState.ready:
      case VoiceChatState.error:
        return Icon(
          _state == VoiceChatState.error ? Icons.error_rounded : Icons.assistant_rounded,
          color: _state == VoiceChatState.error ? const Color(0xFFEF4444) : const Color(0xFF10B981),
          size: 20,
        );
      case VoiceChatState.initializing:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: Color(0xFF10B981),
            strokeWidth: 2,
          ),
        );
    }
  }

  String _getVisibleBoardText() {
    return _currentSpokenText.isNotEmpty
        ? _currentSpokenText
        : (_latestAiReply.isNotEmpty ? _latestAiReply : _panelContent);
  }

  Widget _buildLessonContent(String text) {
    final segments = _splitLessonSegments(text);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final segment in segments) ...[
          if (segment.isMath)
            _buildBoardMathBlock(segment.content)
          else
            MarkdownBody(
              data: segment.content,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                  fontSize: 14,
                  height: 1.55,
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
                  backgroundColor: Colors.grey[850],
                  color: Colors.white,
                  fontFamily: 'RobotoMono',
                  fontSize: 12,
                ),
                codeblockDecoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  List<_LessonSegment> _splitLessonSegments(String text) {
    final pattern = RegExp(
      r'(\$\$[\s\S]+?\$\$|\\\[[\s\S]+?\\\]|\$[^$\n]+\$|\\\([^\n]+?\\\))',
      dotAll: true,
    );

    final segments = <_LessonSegment>[];
    var lastIndex = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastIndex) {
        final plainText = text.substring(lastIndex, match.start).trim();
        if (plainText.isNotEmpty) {
          segments.add(_LessonSegment(plainText, false));
        }
      }

      final rawMath = match.group(0)?.trim() ?? '';
      final cleanMath = rawMath
          .replaceAll(RegExp(r'^\$\$|\$\$$'), '')
          .replaceAll(RegExp(r'^\\\(|\\\)$'), '')
          .replaceAll(RegExp(r'^\\\[|\\\]$'), '')
          .trim();

      if (cleanMath.isNotEmpty) {
        segments.add(_LessonSegment(cleanMath, true));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      final plainText = text.substring(lastIndex).trim();
      if (plainText.isNotEmpty) {
        segments.add(_LessonSegment(plainText, false));
      }
    }

    return segments.isEmpty ? [_LessonSegment(text, false)] : segments;
  }

  Widget _buildBoardMathBlock(String mathContent) {
    final cleanMath = mathContent.replaceAll(r'\over', r'\frac');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1220),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF60A5FA).withOpacity(0.18)),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Math.tex(
            cleanMath,
            textStyle: const TextStyle(
              fontSize: 18,
              color: Colors.white,
            ),
            onErrorFallback: (FlutterMathException e) {
              return SelectableText(
                mathContent,
                style: const TextStyle(
                  color: Color(0xFFE2E8F0),
                  fontFamily: 'RobotoMono',
                  fontSize: 13,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBoardInsightStrip() {
    final visibleText = _getVisibleBoardText();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _state == VoiceChatState.aiSpeaking
                  ? const Color(0xFF10B981)
                  : (_state == VoiceChatState.listening
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF60A5FA)),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              visibleText.isEmpty ? 'Waiting for the lesson to begin.' : visibleText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConceptMapPanel(
    List<String> keywords, {
    required String title,
    required String subtitle,
  }) {
    final centerNode = keywords.isNotEmpty ? keywords.first : 'Concept';
    final supportNodes = keywords.length > 1
        ? keywords.skip(1).take(4).toList()
        : <String>['Example', 'Steps', 'Summary'];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1D4ED8), Color(0xFF0F766E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              centerNode,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: supportNodes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 18,
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Container(
                            width: 2,
                            height: 8,
                            color: const Color(0xFF60A5FA).withOpacity(0.5),
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF60A5FA),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 2,
                            height: 8,
                            color: const Color(0xFF60A5FA).withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF60A5FA).withOpacity(0.18),
                          ),
                        ),
                        child: Text(
                          supportNodes[index],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<String> _extractBoardKeywords(String text) {
    final words = text
        .replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), ' ')
        .split(RegExp(r'\s+'))
        .map((word) => word.trim())
        .where((word) => word.length > 3)
        .where((word) => !_boardStopWords.contains(word.toLowerCase()))
        .toList();

    final unique = <String>[];
    for (final word in words) {
      if (!unique.any((item) => item.toLowerCase() == word.toLowerCase())) {
        unique.add(word);
      }
      if (unique.length == 7) break;
    }

    return unique.isEmpty ? ['Concept', 'Example', 'Summary'] : unique;
  }

  LinearGradient _getMicButtonGradient() {
    switch (_state) {
      case VoiceChatState.initializing:
      case VoiceChatState.processing:
        return const LinearGradient(
          colors: [Color(0xFF475569), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
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
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  Color _getMicButtonColor() {
    switch (_state) {
      case VoiceChatState.initializing:
      case VoiceChatState.processing:
        return const Color(0xFF475569);
      case VoiceChatState.listening:
        return const Color(0xFFEF4444);
      case VoiceChatState.ready:
      case VoiceChatState.error:
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF10B981);
    }
  }

  String _getMicButtonText() {
    switch (_state) {
      case VoiceChatState.initializing:
        return 'Preparing microphone...';
      case VoiceChatState.listening:
        return 'TAP TO STOP';
      case VoiceChatState.processing:
        return 'Please wait...';
      case VoiceChatState.aiSpeaking:
        return 'AI Speaking - Tap to interrupt';
      case VoiceChatState.ready:
        return 'TAP TO SPEAK';
      case VoiceChatState.error:
        return 'Tap to retry';
    }
  }

  bool _canInteractWithMic() {
    return _state != VoiceChatState.initializing &&
        _state != VoiceChatState.processing;
  }

  String _getPanelSubtitle() {
    switch (_state) {
      case VoiceChatState.listening:
        return 'Listening to your voice...';
      case VoiceChatState.processing:
        return 'Processing your request...';
      case VoiceChatState.aiSpeaking:
        return 'AI is explaining...';
      case VoiceChatState.ready:
        return 'Ready for questions';
      case VoiceChatState.error:
        return 'Error occurred';
      case VoiceChatState.initializing:
        return 'Initializing...';
    }
  }

  @override
  void dispose() {
    _silenceTimer?.cancel();
    _restartTimer?.cancel();
    try {
      if (_speech.isListening) _speech.stop();
    } catch (e) {
      // ignore
    }
    _tts.stop();
    _panelScrollController.dispose();
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

class _LessonSegment {
  final String content;
  final bool isMath;

  const _LessonSegment(this.content, this.isMath);
}

const Set<String> _boardStopWords = {
  'this',
  'that',
  'with',
  'from',
  'have',
  'your',
  'about',
  'there',
  'their',
  'would',
  'could',
  'should',
  'because',
  'while',
  'where',
  'which',
  'when',
  'what',
  'into',
  'than',
  'then',
  'them',
  'they',
  'will',
  'just',
  'also',
  'some',
  'more',
  'using',
  'used',
  'user',
  'explain',
  'explaining',
  'ready',
  'listen',
  'listening',
};
