class UserProfile {
  const UserProfile({
    this.id = 'user-01',
    this.name = 'Alex Mercer',
    this.email = 'alex.mercer@lumivo.io',
    this.avatarUrl = '',
    this.language = 'en', // 'en' | 'vi'
    this.themeMode = 'dark', // 'dark' | 'oled'
    this.accentColor = 0xFF8B7CFF,
    this.reducedMotion = false,
    this.temperatureUnit = 'C', // 'C' | 'F'
  });

  final String id;
  final String name;
  final String email;
  final String avatarUrl;
  final String language;
  final String themeMode;
  final int accentColor;
  final bool reducedMotion;
  final String temperatureUnit;

  UserProfile copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    String? language,
    String? themeMode,
    int? accentColor,
    bool? reducedMotion,
    String? temperatureUnit,
  }) =>
      UserProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        language: language ?? this.language,
        themeMode: themeMode ?? this.themeMode,
        accentColor: accentColor ?? this.accentColor,
        reducedMotion: reducedMotion ?? this.reducedMotion,
        temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'avatarUrl': avatarUrl,
        'language': language,
        'themeMode': themeMode,
        'accentColor': accentColor,
        'reducedMotion': reducedMotion,
        'temperatureUnit': temperatureUnit,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String? ?? 'user-01',
        name: json['name'] as String? ?? 'Alex Mercer',
        email: json['email'] as String? ?? 'alex.mercer@lumivo.io',
        avatarUrl: json['avatarUrl'] as String? ?? '',
        language: json['language'] as String? ?? 'en',
        themeMode: json['themeMode'] as String? ?? 'dark',
        accentColor: json['accentColor'] as int? ?? 0xFF8B7CFF,
        reducedMotion: json['reducedMotion'] as bool? ?? false,
        temperatureUnit: json['temperatureUnit'] as String? ?? 'C',
      );
}
