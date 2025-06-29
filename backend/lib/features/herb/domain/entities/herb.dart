class Herb {
  final String id;
  final String thaiName;
  final String scientificName;
  final String harvestSeason;
  final List<String> growingRegions;

  Herb({
    required this.id,
    required this.thaiName,
    required this.scientificName,
    required this.harvestSeason,
    required this.growingRegions,
  });

  factory Herb.fromJson(Map<String, dynamic> json) => Herb(
        id: json['id'],
        thaiName: json['thaiName'],
        scientificName: json['scientificName'],
        harvestSeason: json['harvestSeason'],
        growingRegions: List<String>.from(json['growingRegions']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'thaiName': thaiName,
        'scientificName': scientificName,
        'harvestSeason': harvestSeason,
        'growingRegions': growingRegions,
      };
}
