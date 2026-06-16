import 'package:flutter_app/core/services/api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
///
/// Conversation history is now persisted server-side in MongoDB per
/// (user_id, conversation_id).  The client keeps a lightweight local copy
/// as a fallback for anon users and for optimistic UI rendering.
///
/// A stable [_conversationId] is generated once per install and persisted in
/// SharedPreferences so sessions survive app restarts on the same device.
class RagChatbotService {
  static const int _maxHistory = 12;
  static const String _convIdKey = 'chatbot_conversation_id';

  static final List<ChatTurn> _history = [];
  static String? _conversationId;

  // ── Conversation-ID lifecycle ─────────────────────────────────────────────

  /// Load (or generate) a stable conversation ID for this device/user.
  /// Call once at app start or before the first message.
  static Future<String> _getOrCreateConversationId() async {
    if (_conversationId != null) return _conversationId!;
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_convIdKey);
    if (stored != null && stored.isNotEmpty) {
      _conversationId = stored;
      return _conversationId!;
    }
    final fresh = _generateId();
    await prefs.setString(_convIdKey, fresh);
    _conversationId = fresh;
    return _conversationId!;
  }

  static String _generateId() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    // Simple collision-resistant ID without external deps.
    final rand = ts ^ (ts >> 16);
    return 'cv_${ts.toRadixString(36)}_${rand.abs().toRadixString(36)}';
  }

  // ── Public API ────────────────────────────────────────────────────────────

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

    final conversationId = await _getOrCreateConversationId();

    // Send local history as a fallback (server uses DB history for logged-in
    // users; this is only used for anon sessions).
    final trimmedHistory = _history.length > _maxHistory
        ? _history.sublist(_history.length - _maxHistory)
        : List<ChatTurn>.from(_history);

    try {
      final result = await ApiClient.post(
        '/chatbot/chat',
        body: {
          'message': message,
          'conversation_id': conversationId,
          'history': trimmedHistory.map((t) => t.toJson()).toList(),
        },
      ) as Map<String, dynamic>;

      final response = (result['response'] as String?) ?? '';
      final followRaw = result['follow_up_questions'];
      final followUps = followRaw is List
          ? followRaw.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList()
          : <String>[];
      final closing = result['session_closing'] == true;

      // Keep local copy in sync for anon fallback.
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

  /// Clear conversation history (e.g. on logout or explicit new-chat).
  /// Generates a fresh conversation_id so the next session starts clean.
  static Future<void> resetConversation() async {
    _history.clear();
    _conversationId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_convIdKey);
  }
}
