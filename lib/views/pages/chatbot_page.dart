import 'package:flutter/material.dart';
import '../../services/dialogflow_service.dart';
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
  late AnimationController _typingAnimController;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _typingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _addBotMessage(
        "Hey! Let's talk about food, nutrition, and healthy eating. What do you need help with?");

    // Initial scroll to bottom
    _scrollToBottom();
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
    if (!mounted) return;
    setState(() {
      _messages.add({
        'text': message,
        'isUser': false,
        'time': DateTime.now(),
      });
    });

    // Ensure we scroll to bottom when bot message is added
    _scrollToBottom();
  }

  void _sendMessage() async {
    String message = _controller.text.trim();
    if (message.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _messages.add({
        'text': message,
        'isUser': true,
        'time': DateTime.now(),
      });
      _controller.clear();
      _isLoading = true;
    });

    // Scroll to the bottom immediately after user message is added
    _scrollToBottom();

    try {
      if (mounted) await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      final response = await DialogflowService.sendMessage(message);

      if (!mounted) return;
      _addBotMessage(response);
    } catch (e) {
      if (mounted) {
        _addBotMessage(
            "Sorry, I'm having technical difficulties. Please try again later.");
        print("Error sending message to Dialogflow: $e");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }

    // Scroll to the bottom again after the bot responds
    _scrollToBottom();
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
              children: const [
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
                        child: Text(
                          message['text'],
                          style: TextStyle(
                            fontSize: 15,
                            color: isUser ? Colors.white : Colors.black87,
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
          const SizedBox(height: 20),
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
