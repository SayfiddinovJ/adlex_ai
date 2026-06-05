import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/chat_service.dart';

// ─── Model ────────────────────────────────────────────────────
enum MessageType { text, audio }

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final MessageType type;
  final String? audioPath;
  final String? audioDuration;
  final bool isLoading;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.type = MessageType.text,
    this.audioPath,
    this.audioDuration,
    this.isLoading = false,
  });

  ChatMessage copyWith({String? text, bool? isLoading}) => ChatMessage(
    id: id,
    text: text ?? this.text,
    isUser: isUser,
    type: type,
    audioPath: audioPath,
    audioDuration: audioDuration,
    isLoading: isLoading ?? this.isLoading,
  );
}

// ─── Screen ───────────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final ChatService _service = ChatService();

  bool _isTyping = false;
  bool _isRecording = false;
  bool _isSending = false;
  String _recordDuration = '0:00';

  // Stopwatch uchun
  late AnimationController _micAnim;
  Duration _elapsed = Duration.zero;
  DateTime? _recordStart;

  final List<ChatMessage> _messages = [
    ChatMessage(
      id: 'welcome',
      text:
      "Assalomu alaykum! Adlex AI huquqiy yordamchisiga xush kelibsiz.\n\nMuammoingizni yozing yoki ovozli xabar orqali yuboring — men Lex.uz qonun hujjatlariga asoslanib javob beraman.",
      isUser: false,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _micAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _textCtrl.addListener(() {
      final typing = _textCtrl.text.trim().isNotEmpty;
      if (typing != _isTyping) setState(() => _isTyping = typing);
    });
  }

  @override
  void dispose() {
    _micAnim.dispose();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _service.dispose();
    super.dispose();
  }

  // ── Scroll ──────────────────────────────────────────────────
  void _scrollToBottom({int delay = 100}) {
    Future.delayed(Duration(milliseconds: delay), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Matn yuborish ────────────────────────────────────────────
  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    HapticFeedback.lightImpact();
    _textCtrl.clear();
    setState(() => _isSending = true);

    // Foydalanuvchi xabari
    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: true,
    );

    // AI yuklanish placeholder
    final loadingId = 'loading_${DateTime.now().millisecondsSinceEpoch}';
    final loadingMsg = ChatMessage(
      id: loadingId,
      text: '',
      isUser: false,
      isLoading: true,
    );

    setState(() {
      _messages.add(userMsg);
      _messages.add(loadingMsg);
    });
    _scrollToBottom();

    try {
      final reply = await _service.sendMessage(text);
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == loadingId);
        if (idx != -1) {
          _messages[idx] = _messages[idx].copyWith(
            text: reply,
            isLoading: false,
          );
        }
      });
    } catch (e) {
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == loadingId);
        if (idx != -1) {
          _messages[idx] = _messages[idx].copyWith(
            text: '❌ Xatolik: serverga ulanib bo\'lmadi. Qayta urinib ko\'ring.',
            isLoading: false,
          );
        }
      });
    } finally {
      setState(() => _isSending = false);
      _scrollToBottom(delay: 150);
    }
  }

  // ── Audio yozuv boshlash ─────────────────────────────────────
  Future<void> _startRecording() async {
    try {
      final started = await _service.startRecording();
      if (!started) {
        _showSnack('Mikrofon ruxsati berilmagan', isError: true);
        return;
      }
      setState(() {
        _isRecording = true;
        _recordStart = DateTime.now();
        _recordDuration = '0:00';
        _elapsed = Duration.zero;
      });
      // Har soniyada vaqtni yangilash
      _updateRecordTimer();
    } catch (e) {
      _showSnack('Yozuvni boshlashda xatolik: $e', isError: true);
    }
  }

  void _updateRecordTimer() async {
    while (_isRecording && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (!_isRecording || !mounted) break;
      final elapsed = DateTime.now().difference(_recordStart!);
      setState(() {
        _elapsed = elapsed;
        final m = elapsed.inMinutes;
        final s = elapsed.inSeconds % 60;
        _recordDuration = '$m:${s.toString().padLeft(2, '0')}';
      });
    }
  }

  // ── Audio yozuvni to'xtatib yuborish ────────────────────────
  Future<void> _stopAndSendRecording() async {
    if (!_isRecording) return;
    HapticFeedback.mediumImpact();

    final duration = _recordDuration;
    setState(() => _isRecording = false);

    try {
      final path = await _service.stopRecording();
      if (path == null) {
        _showSnack('Yozuv saqlanmadi', isError: true);
        return;
      }

      // Audio xabarni chatga qo'shish
      final audioMsg = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: '🎤 Ovozli xabar',
        isUser: true,
        type: MessageType.audio,
        audioPath: path,
        audioDuration: duration,
      );

      // AI yuklanish placeholder
      final loadingId = 'loading_${DateTime.now().millisecondsSinceEpoch}';
      final loadingMsg = ChatMessage(
        id: loadingId,
        text: '',
        isUser: false,
        isLoading: true,
      );

      setState(() {
        _messages.add(audioMsg);
        _messages.add(loadingMsg);
        _isSending = true;
      });
      _scrollToBottom();

      // Backend ga audio yuborish
      final reply = await _service.sendAudio(path);
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == loadingId);
        if (idx != -1) {
          _messages[idx] =
              _messages[idx].copyWith(text: reply, isLoading: false);
        }
      });
    } catch (e) {
      _showSnack('Ovoz yuborishda xatolik: $e', isError: true);
    } finally {
      setState(() => _isSending = false);
      _scrollToBottom(delay: 150);
    }
  }

  // ── Yozuvni bekor qilish ─────────────────────────────────────
  Future<void> _cancelRecording() async {
    HapticFeedback.lightImpact();
    await _service.cancelRecording();
    setState(() => _isRecording = false);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.errorRed : AppColors.primary,
      duration: const Duration(seconds: 2),
    ));
  }

  // ─── Build ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _isRecording ? _buildRecordingBar() : _buildInputPanel(),
        ],
      ),
    );
  }

  // ── AppBar ───────────────────────────────────────────────────
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.gavel_rounded,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Adlex AI',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary)),
              Text('Huquqiy maslahatchi',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 14),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF86EFAC)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: Color(0xFF16A34A), shape: BoxShape.circle)),
              const SizedBox(width: 4),
              const Text('Faol',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF15803D))),
            ],
          ),
        ),
      ],
    );
  }

  // ── Message list ─────────────────────────────────────────────
  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        // Birinchi xabar — special welcome
        if (msg.id == 'welcome') return _WelcomeBubble(text: msg.text);
        if (msg.isLoading) return _LoadingBubble();
        if (msg.type == MessageType.audio) return _AudioBubble(msg: msg);
        return _TextBubble(msg: msg);
      },
    );
  }

  // ── Input panel ──────────────────────────────────────────────
  Widget _buildInputPanel() {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Matn maydoni
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 48, maxHeight: 120),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Icon(Icons.gavel_rounded,
                        color: AppColors.textSecondary.withOpacity(0.5),
                        size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      maxLines: null,
                      minLines: 1,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 15),
                      decoration: const InputDecoration(
                        hintText: "Muammoni yozing...",
                        hintStyle: TextStyle(
                            color: AppColors.textSecondary, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Dinamik tugma
          GestureDetector(
            onTap: _isTyping ? _sendText : null,
            onLongPress: _isTyping ? null : _startRecording,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _isSending
                    ? AppColors.primary.withOpacity(0.6)
                    : AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isSending
                  ? const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
                  : Icon(
                _isTyping
                    ? Icons.send_rounded
                    : Icons.mic_none_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Recording bar ─────────────────────────────────────────────
  Widget _buildRecordingBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Bekor qilish
          GestureDetector(
            onTap: _cancelRecording,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.errorRed, size: 22),
            ),
          ),
          const SizedBox(width: 12),

          // Pulsing dot + vaqt
          Expanded(
            child: Row(
              children: [
                FadeTransition(
                  opacity: _micAnim,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '🎙 Yozilmoqda... $_recordDuration',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          // Yuborish
          GestureDetector(
            onTap: _stopAndSendRecording,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bubble Widgets ───────────────────────────────────────────

class _WelcomeBubble extends StatelessWidget {
  final String text;
  const _WelcomeBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.06),
            AppColors.primary.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.gavel_rounded,
                color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.55)),
          ),
        ],
      ),
    );
  }
}

class _TextBubble extends StatelessWidget {
  final ChatMessage msg;
  const _TextBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
      msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: msg.isUser ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(msg.isUser ? 16 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 16),
          ),
          border: msg.isUser
              ? null
              : Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!msg.isUser) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.gavel_rounded,
                      color: AppColors.gold, size: 12),
                  SizedBox(width: 4),
                  Text('Adlex AI',
                      style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 10,
                          fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Text(
              msg.text,
              style: TextStyle(
                color: msg.isUser
                    ? Colors.white
                    : AppColors.textPrimary,
                fontSize: 14.5,
                height: 1.45,
                fontWeight: msg.isUser
                    ? FontWeight.w500
                    : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Audio bubble
class _AudioBubble extends StatefulWidget {
  final ChatMessage msg;
  const _AudioBubble({required this.msg});

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Play/Pause tugma
            GestureDetector(
              onTap: () {
                setState(() => _isPlaying = !_isPlaying);
                // Keyinchalik audio player shu yerda
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // To'lqin + vaqt
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Waveform vizual
                  Row(
                    children: List.generate(
                      20,
                          (i) => Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          height: (i % 3 == 0
                              ? 16.0
                              : i % 2 == 0
                              ? 10.0
                              : 6.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(
                                _isPlaying ? 1.0 : 0.5),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.msg.audioDuration ?? '0:00',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Loading bubble
class _LoadingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Dot(delay: 0),
            const SizedBox(width: 4),
            _Dot(delay: 150),
            const SizedBox(width: 4),
            _Dot(delay: 300),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
    _anim = Tween(begin: 0.3, end: 1.0).animate(CurvedAnimation(
        parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.textSecondary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
