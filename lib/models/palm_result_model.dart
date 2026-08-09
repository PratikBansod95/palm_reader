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

  bool get isLiveAi =>
      source == AnalysisSource.openrouter || source == AnalysisSource.backend;

  factory PalmResultModel.fromMap(Map<String, dynamic> map) {
    return PalmResultModel(
      fullReading: map['fullReading'] as String? ?? map['reading'] as String? ?? '',
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
    );
  }
}
