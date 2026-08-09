enum AnalysisSource { demo, openrouter, backend }

class PalmResultModel {
  const PalmResultModel({
    required this.fullReading,
    required this.personality,
    required this.lifePath,
    required this.love,
    required this.wealth,
    required this.challenges,
    required this.guidance,
    required this.followUps,
    this.source = AnalysisSource.demo,
    this.handLabel = '',
    this.opening = '',
    this.blessing = '',
  });

  final String fullReading;
  final String personality;
  final String lifePath;
  final String love;
  final String wealth;
  final String challenges;
  final String guidance;
  final List<String> followUps;
  final AnalysisSource source;
  final String handLabel;
  final String opening;
  final String blessing;

  bool get isLiveAi =>
      source == AnalysisSource.openrouter || source == AnalysisSource.backend;

  bool get isUnclearHand =>
      handLabel.trim().toLowerCase() == 'unclear';

  bool get hasStructuredSections =>
      opening.trim().isNotEmpty ||
      personality.trim().isNotEmpty ||
      lifePath.trim().isNotEmpty ||
      love.trim().isNotEmpty ||
      wealth.trim().isNotEmpty ||
      challenges.trim().isNotEmpty ||
      guidance.trim().isNotEmpty ||
      blessing.trim().isNotEmpty;

  factory PalmResultModel.fromMap(Map<String, dynamic> map) {
    return PalmResultModel(
      fullReading:
          map['fullReading'] as String? ?? map['reading'] as String? ?? '',
      personality: map['personality'] as String? ?? '',
      lifePath: map['lifePath'] as String? ?? '',
      love: map['love'] as String? ?? '',
      wealth: map['wealth'] as String? ?? '',
      challenges: map['challenges'] as String? ?? '',
      guidance: map['guidance'] as String? ?? '',
      followUps: (map['followUps'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      source: AnalysisSource.demo,
      handLabel: map['handLabel'] as String? ?? '',
      opening: map['opening'] as String? ?? '',
      blessing: map['blessing'] as String? ?? '',
    );
  }

  /// Parses labeled AI output; falls back to narrative paragraphs.
  factory PalmResultModel.fromAiText(
    String raw, {
    required AnalysisSource source,
  }) {
    final text = raw.trim();
    if (text.isEmpty) {
      return PalmResultModel(
        fullReading: '',
        personality: '',
        lifePath: '',
        love: '',
        wealth: '',
        challenges: '',
        guidance: '',
        followUps: const [],
        source: source,
      );
    }

    final fields = _extractLabeledFields(text);
    final opening = fields['OPENING'] ?? '';
    final personality = fields['PERSONALITY'] ?? '';
    final lifePath = fields['LIFE_PATH'] ?? fields['LIFEPATH'] ?? '';
    final love = fields['LOVE'] ?? '';
    final wealth = fields['PROSPERITY'] ?? fields['WEALTH'] ?? '';
    final challenges = fields['CHALLENGES'] ?? '';
    final guidance = fields['GUIDANCE'] ?? '';
    final blessing = fields['BLESSING'] ?? '';
    final handLabel = fields['HAND'] ?? '';

    final hasLabels = personality.isNotEmpty ||
        lifePath.isNotEmpty ||
        love.isNotEmpty ||
        wealth.isNotEmpty ||
        challenges.isNotEmpty ||
        guidance.isNotEmpty ||
        opening.isNotEmpty;

    if (!hasLabels) {
      return PalmResultModel(
        fullReading: text,
        personality: '',
        lifePath: '',
        love: '',
        wealth: '',
        challenges: '',
        guidance: '',
        followUps: const [],
        source: source,
      );
    }

    final narrative = [
      if (opening.isNotEmpty) opening,
      if (personality.isNotEmpty) personality,
      if (lifePath.isNotEmpty) lifePath,
      if (love.isNotEmpty) love,
      if (wealth.isNotEmpty) wealth,
      if (challenges.isNotEmpty) challenges,
      if (guidance.isNotEmpty) guidance,
      if (blessing.isNotEmpty) blessing,
    ].join('\n\n');

    return PalmResultModel(
      fullReading: narrative,
      personality: personality,
      lifePath: lifePath,
      love: love,
      wealth: wealth,
      challenges: challenges,
      guidance: guidance,
      followUps: blessing.isNotEmpty ? [blessing] : const [],
      source: source,
      handLabel: handLabel,
      opening: opening,
      blessing: blessing,
    );
  }

  static Map<String, String> _extractLabeledFields(String text) {
    final labels = <String>[
      'HAND',
      'OPENING',
      'PERSONALITY',
      'LIFE_PATH',
      'LIFEPATH',
      'LOVE',
      'PROSPERITY',
      'WEALTH',
      'CHALLENGES',
      'GUIDANCE',
      'BLESSING',
    ];
    final pattern = RegExp(
      '^(${labels.join('|')})\\s*:\\s*',
      multiLine: true,
      caseSensitive: false,
    );
    final matches = pattern.allMatches(text).toList();
    if (matches.isEmpty) return {};

    final result = <String, String>{};
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final key = match.group(1)!.toUpperCase();
      final start = match.end;
      final end = i + 1 < matches.length ? matches[i + 1].start : text.length;
      result[key] = text.substring(start, end).trim();
    }
    return result;
  }
}
