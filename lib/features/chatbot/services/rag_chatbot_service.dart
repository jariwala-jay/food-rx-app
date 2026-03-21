import 'package:flutter_app/core/services/api_client.dart';

/// Conversation turn in the format expected by the backend RAG service.
class ChatTurn {
  final String role; // "user" or "model"
  final List<String> parts;

  const ChatTurn({required this.role, required this.parts});

  Map<String, dynamic> toJson() => {'role': role, 'parts': parts};
}

/// Service that calls the backend RAG chatbot endpoint.
///
/// Replaces [DialogflowService] — keeps the same public API so [ChatbotPage]
/// needs minimal changes.
class RagChatbotService {
  static const int _maxHistory = 12; // max turns sent to backend

  /// In-memory conversation history (for the current app session).
  static final List<ChatTurn> _history = [];

  /// Send [message] to the RAG backend and return the assistant reply.
  static Future<String> sendMessage(String message) async {
    if (message.trim().isEmpty) return '';

    // Trim history to keep context window manageable
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

      // Append both turns to local history
      _history.add(ChatTurn(role: 'user', parts: [message]));
      _history.add(ChatTurn(role: 'model', parts: [response]));

      return response;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        return "Please log in to use the chatbot.";
      }
      return "Sorry, I'm having trouble connecting right now. Please try again.";
    } catch (_) {
      return "Sorry, something went wrong. Please try again later.";
    }
  }

  /// Clear conversation history (e.g. when user logs out).
  static void resetConversation() => _history.clear();
}
