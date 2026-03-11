class User {
  final String id;
  final String? orgId;
  final String? branchId;
  final String name;
  final String email;
  final String role;
  final bool isActive;

  const User({
    required this.id,
    this.orgId,
    this.branchId,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
        id: j['id'],
        orgId: j['org_id'],
        branchId: j['branch_id'],
        name: j['name'],
        email: j['email'],
        role: j['role'],
        isActive: j['is_active'],
      );
}
