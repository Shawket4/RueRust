import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/branch.dart';
import 'client.dart';

class BranchApi {
  final DioClient _c;
  BranchApi(this._c);

  Future<Branch> get(String branchId) async {
    final res = await _c.dio.get('/branches/$branchId');
    return Branch.fromJson(res.data as Map<String, dynamic>);
  }
}

final branchApiProvider = Provider<BranchApi>(
    (ref) => BranchApi(ref.watch(dioClientProvider)));
