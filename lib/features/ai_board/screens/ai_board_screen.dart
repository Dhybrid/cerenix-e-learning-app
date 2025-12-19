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

  // Auto-scroll
  Timer? _autoScrollTimer;

  // Configuration
  static const _silenceTimeout = Duration(seconds: 3);
  static const _maxRestartAttempts = 30;
  static const _ttsChunkLength = 3500; // Recommended safe max length for TTS chunk

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
        // Start auto-scroll when AI starts speaking
        _startAutoScroll();
      });

      _tts.setCompletionHandler(() {
        if (mounted) {
          // IMPORTANT: Only transition to ready if we are still in aiSpeaking state.
          // This prevents the state from flipping back if the user interrupted.
          if (_state == VoiceChatState.aiSpeaking) {
             setState(() => _state = VoiceChatState.ready);
          }
        }
        // Stop auto-scroll when AI finishes
        _stopAutoScroll();
      });

      _tts.setErrorHandler((msg) {
        print('TTS error: $msg');
        if (mounted) {
          setState(() => _state = VoiceChatState.ready);
        }
        _stopAutoScroll();
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
    });

    _scrollToBottom();
    await _speakText(greeting);
  }

  Future<void> _speakText(String text) async {
    if (text.isEmpty) return;
    
    // Stop any currently speaking text immediately
    if (_state == VoiceChatState.aiSpeaking) {
      await _tts.stop();
      _stopAutoScroll();
    }

    final cleanText = _cleanTextForTTS(text);
    if (cleanText.isEmpty) {
       if (mounted) {
         setState(() => _state = VoiceChatState.ready);
       }
       return;
    }

    // Split long text into manageable chunks
    if (cleanText.length > 500) { // Keep your current threshold
      await _speakLongText(cleanText);
    } else {
      // For short text, use direct speak
      try {
        // State change to aiSpeaking is handled by _tts.setStartHandler
        await _tts.speak(cleanText);
      } catch (e) {
        print('TTS error (short text): $e');
        if (mounted) {
          setState(() => _state = VoiceChatState.ready);
        }
        _stopAutoScroll();
      }
    }
  }

  // UPDATED: Robust splitting logic
  Future<void> _speakLongText(String text) async {
    // 1. Split by sentence end markers (., !, ?) followed by space, while keeping the marker.
    final RegExp sentenceSplitter = RegExp(r'(?<=[.!?])\s+(?=[A-Z0-9]|\s|$)');
    List<String> rawChunks = text.split(sentenceSplitter);
    
    List<String> finalChunks = [];
    String currentChunk = '';

    for (String chunk in rawChunks) {
      final trimmedChunk = chunk.trim();
      if (trimmedChunk.isEmpty) continue;

      if ((currentChunk.length + trimmedChunk.length + 1) > _ttsChunkLength) {
        // If adding this chunk exceeds the limit, push currentChunk and start a new one.
        if (currentChunk.isNotEmpty) {
          finalChunks.add(currentChunk.trim());
        }
        currentChunk = trimmedChunk;
      } else {
        // Otherwise, append to currentChunk.
        currentChunk = (currentChunk.isEmpty ? trimmedChunk : '$currentChunk $trimmedChunk');
      }
    }

    // Add the final chunk if not empty
    if (currentChunk.isNotEmpty) {
      finalChunks.add(currentChunk.trim());
    }

    // 2. Speak each final chunk sequentially
    for (String chunk in finalChunks) {
      if (chunk.isEmpty) continue;
      
      // Crucial check: if the state changes (e.g., user tapped the mic), stop.
      if (_state != VoiceChatState.aiSpeaking) {
        print('TTS interrupted during long text playback loop.');
        break;
      }
      
      try {
        await _tts.speak(chunk);
        // Small delay for natural pacing between large chunks
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        print('TTS error for chunk: $e');
        if (mounted) {
          setState(() => _state = VoiceChatState.ready);
        }
        _stopAutoScroll();
        break;
      }
    }
    
    // Manually handle the final state transition if the loop completed naturally.
    // The setCompletionHandler will fire, but we ensure state is ready if no interruption occurred.
    if (mounted && _state == VoiceChatState.aiSpeaking) {
      setState(() => _state = VoiceChatState.ready);
    }
    _stopAutoScroll();
  }

  // UPDATED: Removed the hard text length limit
  String _cleanTextForTTS(String text) {
    String cleaned = text;
    // Remove markdown code blocks
    cleaned = cleaned.replaceAll(RegExp(r'```[\s\S]*?```'), 'Code block');
    cleaned = cleaned.replaceAll(RegExp(r'`([^`]+)`'), r'code');
    // Remove markdown formatting (except for headers, which TTS can handle as pauses)
    cleaned = cleaned.replaceAll(RegExp(r'\*\*|\*|__|_'), ''); 
    // Remove links (only keep the link text)
    cleaned = cleaned.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');
    // Remove LaTeX/Math formulas for simpler TTS (keep the description or simplify)
    // You might need a more complex regex for robust LaTeX cleaning, but this covers basic inline/block.
    cleaned = cleaned.replaceAll(RegExp(r'\$[^$]*?\$'), 'Formula'); 
    cleaned = cleaned.replaceAll(RegExp(r'\\\((.*?)\\\)'), 'Formula');
    cleaned = cleaned.replaceAll(RegExp(r'\\\[(.*?)\\\]'), 'Formula');
    // Simple emoji removal - avoids complex regex
    cleaned = cleaned.replaceAll(RegExp(r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{1F1E0}-\u{1F1FF}]', unicode: true), '');

    // Clean up whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    
    // NOTE: Hard length limit is removed to support full responses via chunking in _speakLongText
    
    return cleaned.trim();
  }

  // --- REST OF THE CODE REMAINS THE SAME ---

  void _startContinuousListening() async {
    print('=== STARTING CONTINUOUS LISTENING ===');

    if (_state == VoiceChatState.aiSpeaking) {
      await _tts.stop();
      _stopAutoScroll();
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
    });

    _scrollToBottom();
    _startSpeechRecognition();
  }

  void _startSpeechRecognition() async {
    if (!_isContinuousListening || _userStopped) return;

    print('Starting speech recognition... (attempt ${_speechRestartCount + 1})');

    try {
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

          _silenceTimer?.cancel();
          _silenceTimer = Timer(_silenceTimeout, () {
            print('Detected a short silence (but will continue listening).');
          });
        },
        listenMode: stt.ListenMode.dictation,
        localeId: "en-US",
        cancelOnError: true,
        partialResults: true,
        listenFor: const Duration(minutes: 30),
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
    _restartTimer = Timer(const Duration(milliseconds: 300), () async {
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

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_panelScrollController.hasClients) {
        final maxScroll = _panelScrollController.position.maxScrollExtent;
        final currentPosition = _panelScrollController.offset;
        // Scroll only if near the bottom, but not exactly at the end (to prevent jitter)
        if (currentPosition < maxScroll - 10) { 
          _panelScrollController.animateTo(
            currentPosition + 20,
            duration: const Duration(milliseconds: 100),
            curve: Curves.linear,
          );
        } else {
          // If we hit the bottom, stop the timer
          timer.cancel();
        }
      } else {
         // If no clients (e.g., list is empty), stop the timer
         timer.cancel();
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
  }

  void _resetChat() {
    _sessionId = const Uuid().v4();
    _conversationHistory = '';
    _recognizedText = '';
    _fullSessionText = '';

    _silenceTimer?.cancel();
    _restartTimer?.cancel();
    _autoScrollTimer?.cancel();
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

                // Blue Topic Header
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.school_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AI Learning Session',
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

                const SizedBox(height: 8),

                // Panel
                Expanded(
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.6, // Limit height
                    ),
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: SingleChildScrollView(
                      controller: _panelScrollController,
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: MarkdownBody(
                          data: _panelContent,
                          selectable: true,
                          // If you want LaTeX support, you MUST replace MarkdownBody 
                          // with a custom widget or a package like flutter_markdown_latex
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
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
                              fontSize: 13,
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: Colors.grey[900],
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
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
                          GestureDetector(
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
          colors: [Color(0xFF10B981), Color(0xFF059669)],
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
        return const Color(0xFF10B981);
    }
  }

  String _getMicButtonText() {
    switch (_state) {
      case VoiceChatState.initializing:
        return 'Initializing...';
      case VoiceChatState.listening:
        return 'TAP TO STOP';
      case VoiceChatState.processing:
        return 'Processing...';
      case VoiceChatState.aiSpeaking:
        return 'AI Speaking - Tap to interrupt';
      case VoiceChatState.ready:
        return 'TAP TO SPEAK';
      case VoiceChatState.error:
        return 'Tap to retry';
    }
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
    _autoScrollTimer?.cancel();
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