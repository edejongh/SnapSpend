import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoURL;
  final String plan;
  final String? stripeCustomerId;
  final String defaultCurrency;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final bool onboardingComplete;

  const UserModel({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoURL,
    required this.plan,
    this.stripeCustomerId,
    required this.defaultCurrency,
    required this.createdAt,
    required this.lastActiveAt,
    required this.onboardingComplete,
  });

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    String? plan,
    String? stripeCustomerId,
    String? defaultCurrency,
    DateTime? createdAt,
    DateTime? lastActiveAt,
    bool? onboardingComplete,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      plan: plan ?? this.plan,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'plan': plan,
      'stripeCustomerId': stripeCustomerId,
      'defaultCurrency': defaultCurrency,
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
      'onboardingComplete': onboardingComplete,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] as String,
      email: map['email'] as String,
      displayName: map['displayName'] as String?,
      photoURL: map['photoURL'] as String?,
      plan: map['plan'] as String,
      stripeCustomerId: map['stripeCustomerId'] as String?,
      defaultCurrency: map['defaultCurrency'] as String? ?? 'ZAR',
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastActiveAt: DateTime.parse(map['lastActiveAt'] as String),
      onboardingComplete: map['onboardingComplete'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => toMap();

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      UserModel.fromMap(json);

  @override
  List<Object?> get props => [
        uid,
        email,
        displayName,
        photoURL,
        plan,
        stripeCustomerId,
        defaultCurrency,
        createdAt,
        lastActiveAt,
        onboardingComplete,
      ];
}
