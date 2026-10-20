class Room {
  const Room({
    required this.id,
    required this.name,
    this.iconName = 'living_room',
    this.description = '',
    this.homeId = 'home-default',
  });

  final String id;
  final String name;
  final String iconName;
  final String description;
  final String homeId;

  Room copyWith({
    String? id,
    String? name,
    String? iconName,
    String? description,
    String? homeId,
  }) =>
      Room(
        id: id ?? this.id,
        name: name ?? this.name,
        iconName: iconName ?? this.iconName,
        description: description ?? this.description,
        homeId: homeId ?? this.homeId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconName': iconName,
        'description': description,
        'homeId': homeId,
      };

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: json['id'] as String,
        name: json['name'] as String,
        iconName: json['iconName'] as String? ?? 'living_room',
        description: json['description'] as String? ?? '',
        homeId: json['homeId'] as String? ?? 'home-default',
      );
}
