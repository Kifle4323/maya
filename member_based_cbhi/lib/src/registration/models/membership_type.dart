enum MembershipType {
  indigent,
  paying,
}

extension MembershipTypeApi on MembershipType {
  /// API / backend value: `indigent` | `paying`
  String get value => name;
}

class MembershipSelection {
  const MembershipSelection({required this.type, this.premiumAmount});

  final MembershipType type;
  final double? premiumAmount;

  MembershipType get membershipType => type;

  bool get isIndigent => type == MembershipType.indigent;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'premiumAmount': premiumAmount,
      };

  factory MembershipSelection.fromJson(Map<String, dynamic> json) {
    final raw = json['type']?.toString() ?? 'paying';
    var resolved = MembershipType.paying;
    for (final v in MembershipType.values) {
      if (v.name == raw) {
        resolved = v;
        break;
      }
    }
    return MembershipSelection(
      type: resolved,
      premiumAmount: double.tryParse(json['premiumAmount']?.toString() ?? ''),
    );
  }
}
