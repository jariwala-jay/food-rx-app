import 'package:flutter/material.dart';
import 'package:flutter_app/features/chatbot/services/rag_chatbot_service.dart';
import 'dart:math';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({Key? key}) : super(key: key);

  @override
  _ChatbotPageState createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage>
    with TickerProviderStateMixin {
  final _controller = TextEditingController();
  final List<dynamic> _messages = [];
  bool _isLoading = false;
  /// Suggested questions (starters from GET /starter-questions or follow-ups from chat).
  List<String> _suggestionChips = [];
  late AnimationController _typingAnimController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _typingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialMessage());
  }

  Future<void> _loadInitialMessage() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final reply = await RagChatbotService.sendMessage('start');
      if (!mounted) return;
      _addBotMessage(reply.response);
      setState(() {
        _suggestionChips = reply.followUpQuestions;
      });
    } catch (_) {
      if (!mounted) return;
      _addBotMessage(
          "Hey! Let's talk about food, nutrition, and healthy eating. What do you need help with?");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _typingAnimController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // Helper method to scroll to bottom of chat
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addBotMessage(String message) {
    final sanitized = _stripMarkdownTokens(message);
    if (!mounted) return;
    setState(() {
      _messages.add({
        'text': sanitized,
        'isUser': false,
        'time': DateTime.now(),
      });
    });

    // Ensure we scroll to bottom when bot message is added
    _scrollToBottom();
  }

  /// Remove common Markdown syntax so plain chat bubbles remain readable.
  String _stripMarkdownTokens(String input) {
    var text = input;

    // Headers, blockquotes, and list markers.
    text = text.replaceAllMapped(
      RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true),
      (_) => '',
    );
    text = text.replaceAllMapped(
      RegExp(r'^\s*>+\s?', multiLine: true),
      (_) => '',
    );
    text = text.replaceAllMapped(
      RegExp(r'^\s*[-*+]\s+', multiLine: true),
      (_) => '• ',
    );
    text = text.replaceAllMapped(
      RegExp(r'^\s*\d+\.\s+', multiLine: true),
      (_) => '• ',
    );

    // Links: [label](url) -> label
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
      (m) => m.group(1) ?? '',
    );

    // Emphasis and code markers.
    text = text.replaceAll('**', '');
    text = text.replaceAll('__', '');
    text = text.replaceAll('`', '');
    text = text.replaceAll('*', '');
    text = text.replaceAll('_', '');

    // Collapse repeated blank lines/spaces.
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    text = text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
    return text.trim();
  }

  /// Build readable bot text with lightweight formatting:
  /// - keeps bullets
  /// - bolds short "Subheading:" labels (e.g., "Warm up first:")
  Widget _buildBotText(String text, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    final lines = text.split('\n');

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      String? linePrefix;
      final bulletMatch = RegExp(r'^\s*•\s+(.*)$').firstMatch(line);
      final numberMatch = RegExp(r'^\s*(\d+[\.\)])\s+(.*)$').firstMatch(line);
      final content = bulletMatch != null
          ? bulletMatch.group(1) ?? ''
          : numberMatch != null
              ? numberMatch.group(2) ?? ''
              : line.trim();

      if (bulletMatch != null) {
        linePrefix = '• ';
      } else if (numberMatch != null) {
        linePrefix = '${numberMatch.group(1)} ';
      }
      if (linePrefix != null) {
        spans.add(TextSpan(text: linePrefix, style: baseStyle));
      }

      final colonIndex = content.indexOf(':');
      final canBoldLabel = colonIndex > 0 && colonIndex <= 30;
      if (canBoldLabel) {
        final label = content.substring(0, colonIndex + 1).trim();
        final rest = content.substring(colonIndex + 1).trimLeft();
        spans.add(
          TextSpan(
            text: label,
            style: baseStyle.copyWith(fontWeight: FontWeight.w700),
          ),
        );
        if (rest.isNotEmpty) {
          spans.add(TextSpan(text: ' $rest', style: baseStyle));
        }
      } else {
        spans.add(TextSpan(text: content, style: baseStyle));
      }

      if (i < lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: baseStyle));
      }
    }

    return RichText(
      text: TextSpan(children: spans, style: baseStyle),
    );
  }

  void _sendMessage() {
    final message = _controller.text.trim();
    if (message.isEmpty) return;
    _controller.clear();
    _sendUserText(message);
  }

  Future<void> _sendUserText(String message) async {
    if (message.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _messages.add({
        'text': message,
        'isUser': true,
        'time': DateTime.now(),
      });
      _suggestionChips = [];
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      if (mounted) await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      final reply = await RagChatbotService.sendMessage(message);
      if (!mounted) return;
      _addBotMessage(reply.response);
      setState(() {
        _suggestionChips =
            reply.sessionClosing ? <String>[] : reply.followUpQuestions;
      });
    } catch (e) {
      if (mounted) {
        _addBotMessage(
            "Sorry, I'm having technical difficulties. Please try again later.");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
    _scrollToBottom();
  }

  /// Full-width tappable rows so long questions wrap instead of clipping (ActionChip truncates).
  Widget _buildSuggestionChips() {
    if (_suggestionChips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _suggestionChips.map((q) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              child: InkWell(
                onTap: _isLoading ? null : () => _sendUserText(q),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Text(
                    q,
                    textAlign: TextAlign.left,
                    softWrap: true,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: Color(0xFF333333),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Stack(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F1F5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
          // Wedge for bot message
          Positioned(
            left: 0,
            bottom: 8,
            child: ClipPath(
              clipper: CustomTriangleClipperLeft(),
              child: Container(
                width: 12,
                height: 12,
                color: const Color(0xFFF0F1F5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return AnimatedBuilder(
      animation: _typingAnimController,
      builder: (context, child) {
        final double bounce =
            sin((_typingAnimController.value * 3.14 * 2) + (index * 0.4));
        return Transform.translate(
          offset: Offset(0, -2 * bounce),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[600],
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const orangeColor = Color(0xFFFF6A00);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F8),
        elevation: 1,
        leadingWidth: 30,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 22),
          padding: EdgeInsets.zero,
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: orangeColor,
              child: Image.asset(
                'assets/icons/chatbot.png',
                width: 20,
                height: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "ChatBot",
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "● Always active",
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: Text(
                DateFormat('EEE h:mm a').format(DateTime.now()),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _isLoading ? _messages.length + 1 : _messages.length,
              itemBuilder: (context, index) {
                if (_isLoading && index == _messages.length) {
                  return _buildTypingIndicator();
                }

                final message = _messages[index];
                final isUser = message['isUser'];
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isUser ? orangeColor : const Color(0xFFF0F1F5),
                          borderRadius: BorderRadius.circular(16),
                          border: !isUser
                              ? Border.all(color: Colors.grey.withOpacity(0.2))
                              : null,
                        ),
                        child: isUser
                            ? Text(
                                message['text'],
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.white,
                                  height: 1.3,
                                ),
                              )
                            : _buildBotText(
                                message['text'],
                                const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                  height: 1.3,
                                ),
                              ),
                      ),
                      if (isUser)
                        Positioned(
                          right: 0,
                          bottom: 8,
                          child: ClipPath(
                            clipper: CustomTriangleClipper(),
                            child: Container(
                              width: 12,
                              height: 12,
                              color: orangeColor,
                            ),
                          ),
                        ),
                      if (!isUser)
                        Positioned(
                          left: 0,
                          bottom: 8,
                          child: ClipPath(
                            clipper: CustomTriangleClipperLeft(),
                            child: Container(
                              width: 12,
                              height: 12,
                              color: const Color(0xFFF0F1F5),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          _buildSuggestionChips(),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: orangeColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: SvgPicture.asset(
                      'assets/icons/send.svg',
                      color: Colors.white,
                    ),
                    onPressed: _sendMessage,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 20 : 30),
        ],
      ),
    );
  }
}

// Custom clipper for the user message wedge (right side)
class CustomTriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// Custom clipper for the bot message wedge (left side)
class CustomTriangleClipperLeft extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width, 0);
    path.lineTo(0, size.height / 2);
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
