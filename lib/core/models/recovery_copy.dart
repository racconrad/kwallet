class RecoveryCopy {
  final String id;
  final DateTime createdAt;
  final bool beforeUpdate;
  final bool automatic;
  const RecoveryCopy({
    this.automatic = false,
    required this.id,
    required this.createdAt,
    required this.beforeUpdate,
  });
}
