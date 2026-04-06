import 'package:flutter_app/core/services/api_client.dart';

/// One conversation turn in the format expected by the backend RAG service.
class ChatTurn {
  final String role;
  final List<String> parts;

  const ChatTurn({required this.role, required this.parts});

  Map<String, dynamic> toJson() => {'role': role, 'parts': parts};
}

/// RAG chatbot — POST /chatbot/chat on the FastAPI backend.
/// Same static API as [DialogflowService] for minimal call-site changes.
class RagChatbotService {
  static const int _maxHistory = 12;

  static final List<ChatTurn> _history = [];

  static Future<String> sendMessage(String message) async {
    if (message.trim().isEmpty) return '';

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

  /// Clear conversation history (e.g. on logout or app start).
  static void resetConversation() => _history.clear();
}
