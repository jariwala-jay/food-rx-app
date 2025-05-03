import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DialogflowService {
  static late final String _projectId;
  static late final String _location;
  static late final String _agentId;
  static late final String _languageCode;
  static String sessionId = 'flutter-session-001';

  static void initialize() {
    _projectId = dotenv.env['DIALOGFLOW_PROJECT_ID'] ?? '';
    _location = dotenv.env['DIALOGFLOW_LOCATION'] ?? 'global';
    _agentId = dotenv.env['DIALOGFLOW_AGENT_ID'] ?? '';
    _languageCode = dotenv.env['DIALOGFLOW_LANGUAGE_CODE'] ?? 'en';

    if (_projectId.isEmpty) {
      throw Exception(
          'DIALOGFLOW_PROJECT_ID is not set in environment variables');
    }
    if (_agentId.isEmpty) {
      throw Exception(
          'DIALOGFLOW_AGENT_ID is not set in environment variables');
    }
  }

  static String get projectId => _projectId;
  static String get location => _location;
  static String get agentId => _agentId;
  static String get languageCode => _languageCode;

  static const _scopes = ['https://www.googleapis.com/auth/cloud-platform'];

  // Store conversation history to manage context
  static final List<Map<String, dynamic>> _conversationHistory = [];
  static const int _maxHistoryItems = 10;
  static const int _maxContextLength = 200;

  static Future<http.Client> _getAuthClient() async {
    try {
      final serviceAccountJson =
          await rootBundle.loadString('assets/dialogflow_auth.json');
      final serviceAccount =
          ServiceAccountCredentials.fromJson(json.decode(serviceAccountJson));
      return clientViaServiceAccount(serviceAccount, _scopes);
    } catch (e) {
      print('Error initializing DialogFlow auth client: $e');
      return http.Client();
    }
  }

  // Reset the conversation context if needed
  static void resetConversation() {
    _conversationHistory.clear();
    // Generate a new session ID to start fresh
    sessionId = 'flutter-session-${DateTime.now().millisecondsSinceEpoch}';
    print('Conversation reset with new session ID: $sessionId');
  }

  static Future<String> sendMessage(String message) async {
    // If message is too long, truncate it
    if (message.length > 200) {
      message = message.substring(0, 200) + "...";
    }

    http.Client client;
    try {
      client = await _getAuthClient();
    } catch (e) {
      print('Failed to get auth client: $e');
      return "Sorry, I'm having trouble connecting to my services. Please try again later.";
    }

    final url =
        'https://dialogflow.googleapis.com/v3/projects/$projectId/locations/$location/agents/$agentId/sessions/$sessionId:detectIntent';

    // Add the user's message to history
    _conversationHistory.add({'role': 'user', 'content': message});

    // Trim history if it gets too long
    while (_conversationHistory.length > _maxHistoryItems) {
      _conversationHistory.removeAt(0);
    }

    try {
      // Use a simplified request without context to minimize token usage
      final body = {
        "queryInput": {
          "text": {"text": message},
          "languageCode": languageCode
        }
      };

      // Use a timeout to prevent hanging
      final response = await client
          .post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Request took too long to complete');
      });

      if (response.statusCode == 200) {
        final responseJson = jsonDecode(response.body);
        final text = responseJson['queryResult']?['responseMessages']?[0]
            ?['text']?['text']?[0];

        // Store the bot's response in history too
        if (text != null) {
          // Truncate response if it's too long to prevent token issues in future requests
          final truncatedResponse = text.length > _maxContextLength
              ? text.substring(0, _maxContextLength) + "..."
              : text;

          _conversationHistory
              .add({'role': 'assistant', 'content': truncatedResponse});
        }

        return text ?? "Sorry, I didn't understand that.";
      } else {
        print('Error response: ${response.statusCode}: ${response.body}');

        // Check if it's a token limit error and reset the conversation
        if (response.body.contains("Token limit exceeded") ||
            response.body.contains("FAILED_PRECONDITION")) {
          print('Token limit exceeded. Resetting conversation context.');
          resetConversation();
          return "I had to reset our conversation due to technical limitations. What would you like to know about food and nutrition?";
        }

        return "Sorry, I'm having trouble understanding you right now.";
      }
    } catch (e) {
      print('Exception in sendMessage: $e');

      // If it's a timeout, handle it specifically
      if (e is TimeoutException) {
        return "Sorry, it's taking too long to get a response. Please try again later.";
      }

      // If we get any other kind of error, reset the conversation to be safe
      resetConversation();
      return "I encountered a technical issue and had to reset our conversation. How can I help you with food and nutrition?";
    } finally {
      try {
        if (client is AutoRefreshingAuthClient) {
          client.close();
        }
      } catch (e) {
        print('Error closing client: $e');
      }
    }
  }
}
