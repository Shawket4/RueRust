class User {
  final String  id;
  final String? orgId;
  final String? branchId;
  final String  name;
  final String? email;
  final String  role;
  final bool    isActive;

  const User({
    required this.id,
    this.orgId,
    this.branchId,
    required this.name,
    this.email,
    required this.role,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> j) => User(
    id:       j['id']        as String,
    orgId:    j['org_id']    as String?,
    branchId: j['branch_id'] as String?,
    name:     j['name']      as String,
    email:    j['email']     as String?,
    role:     j['role']      as String,
    isActive: j['is_active'] as bool,
  );

  Map<String, dynamic> toJson() => {
    'id': id, 'org_id': orgId, 'branch_id': branchId,
    'name': name, 'email': email, 'role': role, 'is_active': isActive,
  };
}
