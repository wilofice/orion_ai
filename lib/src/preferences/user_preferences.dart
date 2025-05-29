class UserPreferences {
  final bool darkMode;

  UserPreferences({required this.darkMode});

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(darkMode: json['darkMode'] as bool? ?? false);
  }

  Map<String, dynamic> toJson() => {
        'darkMode': darkMode,
      };

  UserPreferences copyWith({bool? darkMode}) {
    return UserPreferences(darkMode: darkMode ?? this.darkMode);
  }
}
