import 'package:flutter_app/core/services/api_client.dart';

/// One conversation turn in the format expected by the backend RAG service.
class ChatTurn {
  final String role;
  final List<String> parts;

  const ChatTurn({required this.role, required this.parts});

  Map<String, dynamic> toJson() => {'role': role, 'parts': parts};
}

/// Result of POST /chatbot/chat — assistant reply plus optional suggested next questions.
class ChatReply {
  final String response;
  final List<String> followUpQuestions;
  /// When true, the user sent a closing signal (thanks, ok, bye, …); hide chip row.
  final bool sessionClosing;

  const ChatReply({
    required this.response,
    this.followUpQuestions = const [],
    this.sessionClosing = false,
  });
}

/// RAG chatbot client — POST /chatbot/chat on the FastAPI backend.
class RagChatbotService {
  static const int _maxHistory = 12;

  static final List<ChatTurn> _history = [];

  /// Profile-based starter questions (GET /chatbot/starter-questions).
  static Future<List<String>> fetchStarterQuestions() async {
    try {
      final result = await ApiClient.get('/chatbot/starter-questions')
          as Map<String, dynamic>?;
      if (result == null) return [];
      final raw = result['questions'];
      if (raw is! List) return [];
      return raw.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<ChatReply> sendMessage(String message) async {
    if (message.trim().isEmpty) {
      return const ChatReply(response: '');
    }

    final trimmedHistory = _history.length > _maxHistory
        ? _history.sublist(_history.length - _maxHistory)
        : List<ChatTurn>.from(_history);

    try {
      final result = await ApiClient.post(
        '/chatbot/chat',
        body: {
          'message': message,
          'history': trimmedHistory.map((t) => t.toJson()).toList(),
        },
      ) as Map<String, dynamic>;

      final response = (result['response'] as String?) ?? '';
      final followRaw = result['follow_up_questions'];
      final followUps = followRaw is List
          ? followRaw.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList()
          : <String>[];
      final closing = result['session_closing'] == true;

      _history.add(ChatTurn(role: 'user', parts: [message]));
      _history.add(ChatTurn(role: 'model', parts: [response]));

      return ChatReply(
        response: response,
        followUpQuestions: followUps,
        sessionClosing: closing,
      );
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        return const ChatReply(
          response: "Please log in to use the chatbot.",
        );
      }
      return const ChatReply(
        response:
            "Sorry, I'm having trouble connecting right now. Please try again.",
      );
    } catch (_) {
      return const ChatReply(
        response: "Sorry, something went wrong. Please try again later.",
      );
    }
  }

  /// Clear conversation history (e.g. on logout or app start).
  static void resetConversation() => _history.clear();
}
