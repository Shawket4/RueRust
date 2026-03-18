import 'client.dart';
import '../models/branch.dart';

class BranchApi {
  Future<Branch> get(String branchId) async {
    final res = await dio.get('/branches/$branchId');
    return Branch.fromJson(res.data as Map<String, dynamic>);
  }
}

final branchApi = BranchApi();

