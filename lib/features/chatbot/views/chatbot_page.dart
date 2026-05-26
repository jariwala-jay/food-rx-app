import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/features/chatbot/services/rag_chatbot_service.dart';
import 'package:flutter_app/features/chatbot/data/chatbot_glossary.dart';
import 'dart:math';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

/// One glossary match in the assistant message (global indices in full text).
class _GlossaryHit {
  final int start;
  final int end;
  final String matched;
  final String canonical;
  final double score;

  const _GlossaryHit({
    required this.start,
    required this.end,
    required this.matched,
    required this.canonical,
    required this.score,
  });
}

/// Cached regex pass + prime highlight picks for one bot bubble.
class _GlossaryLayoutCache {
  final List<_GlossaryHit> hits;

  /// Strongest glossary taps first (primary), then optional second (secondary).
  final List<(int, int)> primeRangesOrdered;
  final Set<String> primeCanonicals;

  _GlossaryLayoutCache({
    required this.hits,
    required this.primeRangesOrdered,
    required this.primeCanonicals,
  });
}

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({Key? key}) : super(key: key);

  @override
  _ChatbotPageState createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage>
    with TickerProviderStateMixin {
  static const _SendButtonStyle _sendButtonStyle = _SendButtonStyle.solid;

  final _controller = TextEditingController();
  final List<dynamic> _messages = [];
  late final RegExp _glossaryRegex;
  bool _isLoading = false;

  List<String> _suggestionChips = [];
  late AnimationController _typingAnimController;
  final ScrollController _scrollController = ScrollController();

  final Set<String> _glossaryPrimeCanonicalsShown = <String>{};
  final Set<String> _glossaryConditionHints = <String>{};
  static const Color _accentOrangeColor = Color(0xFFFF6A00);
  static const Color _userBubbleColor = _accentOrangeColor;
  static const Color _botBubbleColor = Color(0xFFF1F3F5);

  @override
  void initState() {
    super.initState();
    _glossaryRegex = _buildGlossaryRegex();
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

  /// Strip any variant of "you can explore more below" from assistant text (never show in UI).
  static String _stripExploreBelowHint(String text) {
    final lineOnly = RegExp(
      r'^\s*\*?\s*you can explore more below[\.\!…]*\*?\s*$',
      caseSensitive: false,
    );
    final inline = RegExp(
      r'[ \t\*_]*you can explore more below[\.\!…]*[ \t\*_]*',
      caseSensitive: false,
    );
    final out = <String>[];
    for (final line in text.split('\n')) {
      if (lineOnly.hasMatch(line.trim())) {
        continue;
      }
      out.add(line.replaceAll(inline, ''));
    }
    var t = out.join('\n');
    t = t.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return t.trim();
  }

  void _addBotMessage(String message) {
    if (!mounted) return;
    var sanitized = _stripExploreBelowHint(_stripMarkdownTokens(message));
    final sessionBefore = Set<String>.from(_glossaryPrimeCanonicalsShown);
    final shouldSkipHighlights = _shouldSkipGlossaryForMessage(sanitized);
    final layout = shouldSkipHighlights
        ? _GlossaryLayoutCache(
            hits: const <_GlossaryHit>[],
            primeRangesOrdered: const <(int, int)>[],
            primeCanonicals: <String>{},
          )
        : _computeGlossaryLayout(
            sanitized,
            sessionBefore,
            conditionHints: _glossaryConditionHints,
          );
    setState(() {
      _messages.add({
        'text': sanitized,
        'isUser': false,
        'time': DateTime.now(),
        '_glossary': layout,
      });
      _glossaryPrimeCanonicalsShown.addAll(layout.primeCanonicals);
    });

    _scrollToBottom();
  }

  bool _shouldSkipGlossaryForMessage(String text) {
    final normalized = text.trim().toLowerCase();
    if (normalized.isEmpty || normalized.length < 55) return true;

    // Skip intro handshake/greeting bubbles (welcome tone, not content answer).
    final startsLikeGreeting = RegExp(
      r'^(hi|hello|hey)\b',
      caseSensitive: false,
    ).hasMatch(normalized);
    final hasIntroFraming = normalized.contains("i'm here to") ||
        normalized.contains("i’m here to");
    final hasGuidedPrompt = normalized.contains('what would you like') ||
        normalized.contains('where would you like') ||
        normalized.contains('want to explore');
    if (startsLikeGreeting && hasIntroFraming && hasGuidedPrompt) return true;

    final closingPattern = RegExp(
      r'(take care|let me know|anything else|have a (great|good) day|thanks for chatting|happy to help)',
      caseSensitive: false,
    );
    return closingPattern.hasMatch(normalized);
  }

  /// Emoji hint per chip text (rule-based, no network).
  String _getIcon(String text) {
    final t = text.toLowerCase();
    if (t.contains('sleep') || t.contains('rest')) return '😴';
    if (t.contains('water') || t.contains('hydrat')) return '💧';
    if (t.contains('exercise') || t.contains('workout') || t.contains('walk'))
      return '🏃';
    if (t.contains('food') ||
        t.contains('foods') ||
        t.contains('meal') ||
        t.contains('recipe') ||
        t.contains('eat')) return '🍽️';
    if (t.contains('pantry') || t.contains('grocery')) return '🥫';
    if (t.contains('carb') || t.contains('sugar') || t.contains('blood'))
      return '📊';
    if (t.contains('snack')) return '🥕';
    if (t.contains('tip') || t.contains('idea') || t.contains('curious'))
      return '💡';
    return '🍎';
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
  Widget _buildBotText(
      String text, TextStyle baseStyle, _GlossaryLayoutCache? glossary) {
    final cache = glossary ??
        _computeGlossaryLayout(text, {},
            conditionHints: _glossaryConditionHints);
    final spans = <InlineSpan>[];

    /// First interactive (tap) per canonical in this bubble — avoids duplicate links (e.g. "blood sugar" twice).
    final interactiveCanonicalUsed = <String>{};
    final lines = text.split('\n');
    var lineStartOffset = 0;

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

      final contentOffsetInLine = bulletMatch != null
          ? bulletMatch.group(0)!.length - bulletMatch.group(1)!.length
          : numberMatch != null
              ? numberMatch.group(0)!.length - numberMatch.group(2)!.length
              : () {
                  final t = line.trim();
                  if (t.isEmpty) return 0;
                  final idx = line.indexOf(t);
                  return idx >= 0 ? idx : 0;
                }();
      final contentStartInFullText = lineStartOffset + contentOffsetInLine;

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
        final rawRest = content.substring(colonIndex + 1);
        final rest = rawRest.trimLeft();
        spans.add(
          TextSpan(
            text: label,
            style: baseStyle.copyWith(fontWeight: FontWeight.w700),
          ),
        );
        if (rest.isNotEmpty) {
          final leadingSkip = rawRest.length - rest.length;
          final globalRestStart =
              contentStartInFullText + colonIndex + 1 + leadingSkip;
          spans.add(TextSpan(text: ' ', style: baseStyle));
          spans.addAll(
            _buildGlossarySpansFromHits(
              text: rest,
              baseStyle: baseStyle,
              globalOffset: globalRestStart,
              hits: cache.hits,
              primeRangesOrdered: cache.primeRangesOrdered,
              interactiveCanonicalUsed: interactiveCanonicalUsed,
            ),
          );
        }
      } else {
        spans.addAll(
          _buildGlossarySpansFromHits(
            text: content,
            baseStyle: baseStyle,
            globalOffset: contentStartInFullText,
            hits: cache.hits,
            primeRangesOrdered: cache.primeRangesOrdered,
            interactiveCanonicalUsed: interactiveCanonicalUsed,
          ),
        );
      }

      lineStartOffset += line.length;
      if (i < lines.length - 1) {
        spans.add(TextSpan(text: '\n', style: baseStyle));
        lineStartOffset += 1;
      }
    }

    return RichText(
      text: TextSpan(children: spans, style: baseStyle),
    );
  }

  /// Single regex pass + prime selection (session skip, per-message canonical dedup, max 2).
  _GlossaryLayoutCache _computeGlossaryLayout(
    String fullText,
    Set<String> sessionBefore, {
    Set<String>? conditionHints,
  }) {
    final matches = _glossaryRegex.allMatches(fullText).toList();
    final hits = <_GlossaryHit>[];
    final hints = conditionHints ?? _glossaryConditionHints;

    for (final m in matches) {
      final matchedText = m.group(0)!;
      final normalized = ChatbotGlossary.normalizeTerm(matchedText);
      final canonical = ChatbotGlossary.aliases[normalized] ?? normalized;
      final definition = ChatbotGlossary.definitions[canonical];
      if (definition == null) continue;

      final baseScore = ChatbotGlossary.highlightPriority[canonical] ??
          ChatbotGlossary.highlightPriorityDefault;
      final rawBoost = ChatbotGlossary.conditionPriorityBoost(canonical, hints);
      final isNovel = !sessionBefore.contains(canonical);
      final combined = ChatbotGlossary.combinedHighlightScore(
        baseScore: baseScore,
        conditionBoostRaw: rawBoost,
        isNovel: isNovel,
      );
      hits.add(
        _GlossaryHit(
          start: m.start,
          end: m.end,
          matched: matchedText,
          canonical: canonical,
          score: combined,
        ),
      );
    }

    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return a.start.compareTo(b.start);
    });

    final primeRangesOrdered = <(int, int)>[];
    final primeCanonicals = <String>{};
    final usedCanonicalThisMessage = <String>{};
    final usedSemanticGroups = <String>{};

    for (final h in hits) {
      if (primeRangesOrdered.length >=
          ChatbotGlossary.maxHighlightsPerMessage) {
        break;
      }
      if (sessionBefore.contains(h.canonical)) continue;
      if (usedCanonicalThisMessage.contains(h.canonical)) continue;

      final semanticGroup =
          ChatbotGlossary.semanticGroupForCanonical(h.canonical);
      if (semanticGroup != null && usedSemanticGroups.contains(semanticGroup)) {
        continue;
      }

      final overlaps = primeRangesOrdered.any(
        (r) => _rangesOverlap(r.$1, r.$2, h.start, h.end),
      );
      if (overlaps) continue;

      primeRangesOrdered.add((h.start, h.end));
      primeCanonicals.add(h.canonical);
      usedCanonicalThisMessage.add(h.canonical);
      if (semanticGroup != null) {
        usedSemanticGroups.add(semanticGroup);
      }
    }

    return _GlossaryLayoutCache(
      hits: hits,
      primeRangesOrdered: primeRangesOrdered,
      primeCanonicals: primeCanonicals,
    );
  }

  bool _rangesOverlap(int a0, int a1, int b0, int b1) {
    return a0 < b1 && b0 < a1;
  }

  RegExp _buildGlossaryRegex() {
    final allTerms = <String>{
      ...ChatbotGlossary.definitions.keys,
      ...ChatbotGlossary.aliases.keys,
    }.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    final pattern = allTerms.map(RegExp.escape).join('|');
    return RegExp(
      '(?<![A-Za-z0-9])($pattern)(?![A-Za-z0-9])',
      caseSensitive: false,
    );
  }

  static const Color _glossaryPrimeColor = Color(0xFF4A6FA5);

  List<InlineSpan> _buildGlossarySpansFromHits({
    required String text,
    required TextStyle baseStyle,
    required int globalOffset,
    required List<_GlossaryHit> hits,
    required List<(int, int)> primeRangesOrdered,
    required Set<String> interactiveCanonicalUsed,
  }) {
    if (text.trim().isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final endExclusive = globalOffset + text.length;
    final segmentHits = hits
        .where((h) => h.start >= globalOffset && h.end <= endExclusive)
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    final primeRank = <(int, int), int>{
      for (var i = 0; i < primeRangesOrdered.length; i++)
        primeRangesOrdered[i]: i,
    };

    final spans = <InlineSpan>[];
    var cursor = 0;

    for (final h in segmentHits) {
      final localStart = h.start - globalOffset;
      final localEnd = h.end - globalOffset;
      if (localStart < cursor || localEnd > text.length) continue;

      if (localStart > cursor) {
        spans.add(
          TextSpan(
            text: text.substring(cursor, localStart),
            style: baseStyle,
          ),
        );
      }

      final slice = text.substring(localStart, localEnd);
      final definition = ChatbotGlossary.definitions[h.canonical];
      final primeIdx = primeRank[(h.start, h.end)];
      final isPrime = primeIdx != null;

      if (definition == null || !isPrime) {
        spans.add(TextSpan(text: slice, style: baseStyle));
      } else if (interactiveCanonicalUsed.contains(h.canonical)) {
        final isPrimary = primeIdx == 0;
        final duplicateStyle = isPrimary
            ? baseStyle.copyWith(
                color: _glossaryPrimeColor.withValues(alpha: 0.95),
                decoration: TextDecoration.underline,
                decorationThickness: 1.15,
                fontWeight: FontWeight.w700,
              )
            : baseStyle.copyWith(
                color: _glossaryPrimeColor.withValues(alpha: 0.78),
                decoration: TextDecoration.underline,
                decorationThickness: 0.85,
                fontWeight: FontWeight.w600,
              );
        spans.add(TextSpan(text: slice, style: duplicateStyle));
      } else {
        interactiveCanonicalUsed.add(h.canonical);
        final title = ChatbotGlossary.displayTitleForCanonical(h.canonical);
        final isPrimary = primeIdx == 0;
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _GlossaryTapTerm(
              onTap: () => _showGlossaryBottomSheet(
                displayTitle: title,
                definition: definition,
              ),
              child: Text(
                slice,
                style: isPrimary
                    ? baseStyle.copyWith(
                        color: _glossaryPrimeColor.withValues(alpha: 0.98),
                        decoration: TextDecoration.underline,
                        decorationThickness: 1.15,
                        fontWeight: FontWeight.w700,
                      )
                    : baseStyle.copyWith(
                        color: _glossaryPrimeColor.withValues(alpha: 0.78),
                        decoration: TextDecoration.underline,
                        decorationThickness: 0.9,
                        fontWeight: FontWeight.w600,
                      ),
              ),
            ),
          ),
        );
      }

      cursor = localEnd;
    }

    if (cursor < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(cursor),
          style: baseStyle,
        ),
      );
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: baseStyle));
    }
    return spans;
  }

  void _showGlossaryBottomSheet({
    required String displayTitle,
    required String definition,
  }) {
    final primary = _condenseGlossaryDefinition(definition);
    final supporting = _buildWhyItMattersLine(primary, definition);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Text(
                  displayTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  primary,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
                if (supporting != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    supporting,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  String _condenseGlossaryDefinition(String definition) {
    final cleaned = definition.replaceAll(RegExp(r'\s+'), ' ').trim();
    final sentenceMatches =
        RegExp(r'[^.!?]+[.!?]?').allMatches(cleaned).toList();
    if (sentenceMatches.isEmpty) return cleaned;
    final first = sentenceMatches.first.group(0)?.trim() ?? cleaned;
    if (first.length <= 120) {
      return first;
    }
    return '${first.substring(0, 117).trimRight()}...';
  }

  String? _buildWhyItMattersLine(String primary, String fullDefinition) {
    final cleaned = fullDefinition.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned == primary || cleaned.length < 45) return null;

    if (cleaned.contains('blood sugar') ||
        cleaned.contains('blood pressure') ||
        cleaned.contains('heart')) {
      return 'Why it matters: it can improve long-term health outcomes.';
    }
    if (cleaned.contains('full') || cleaned.contains('appetite')) {
      return 'Why it matters: it can help you manage hunger and portions.';
    }
    return 'Why it matters: this can make healthy choices easier day to day.';
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
      if (mounted) await Future.delayed(const Duration(milliseconds: 600));
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _suggestionChips.isEmpty
          ? const SizedBox.shrink(key: ValueKey('sug_empty'))
          : Padding(
              key: ValueKey(_suggestionChips.join('|')),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._suggestionChips.asMap().entries.map((entry) {
                    final q = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Material(
                        color: const Color(0xFFFDFEFF),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color:
                                const Color(0xFFC8D1DE).withValues(alpha: 0.5),
                            width: 0.75,
                          ),
                        ),
                        child: InkWell(
                          splashColor: Colors.grey.withOpacity(0.1),
                          onTap: () {
                            if (_isLoading) return;
                            HapticFeedback.lightImpact();
                            setState(() => _suggestionChips = []);
                            _sendUserText(q);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 11),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getIcon(q),
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    q,
                                    textAlign: TextAlign.left,
                                    softWrap: true,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.35,
                                      color: Color(0xFF3D4652),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
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
              color: _botBubbleColor,
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
                color: _botBubbleColor,
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
              backgroundColor: _accentOrangeColor,
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
                          color: isUser ? _userBubbleColor : _botBubbleColor,
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
                                  height: 1.4,
                                ),
                              )
                            : _buildBotText(
                                message['text'],
                                const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                                message['_glossary'] as _GlossaryLayoutCache?,
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
                              color: _userBubbleColor,
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
                              color: _botBubbleColor,
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
                _buildSendButton(),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 20 : 30),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    switch (_sendButtonStyle) {
      case _SendButtonStyle.solid:
        return _buildSolidSendButton();
      case _SendButtonStyle.gradient:
        return _buildGradientSendButton();
      case _SendButtonStyle.outline:
        return _buildOutlineSendButton();
    }
  }

  Widget _buildSendIcon({required Color color}) {
    return SvgPicture.asset(
      'assets/icons/send.svg',
      width: 22,
      height: 22,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  Widget _buildSolidSendButton() {
    return Material(
      color: _accentOrangeColor,
      elevation: 3,
      shadowColor: Colors.black26,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _sendMessage,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(child: _buildSendIcon(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildGradientSendButton() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF8A00), Color(0xFFFF5E00)],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33FF6A00),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _sendMessage,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(child: _buildSendIcon(color: Colors.white)),
          ),
        ),
      ),
    );
  }

  Widget _buildOutlineSendButton() {
    return Material(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black12,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _accentOrangeColor, width: 2),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _sendMessage,
          child: Center(child: _buildSendIcon(color: _accentOrangeColor)),
        ),
      ),
    );
  }
}

enum _SendButtonStyle {
  solid,
  gradient,
  outline,
}

class _GlossaryTapTerm extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _GlossaryTapTerm({
    required this.child,
    required this.onTap,
  });

  @override
  State<_GlossaryTapTerm> createState() => _GlossaryTapTermState();
}

class _GlossaryTapTermState extends State<_GlossaryTapTerm> {
  bool _pressed = false;

  Future<void> _handleTap() async {
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() => _pressed = true);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (!mounted) return;
    setState(() => _pressed = false);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.85 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
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
