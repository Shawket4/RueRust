import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/discount.dart';
import 'client.dart';

class DiscountApi {
  final DioClient _c;
  DiscountApi(this._c);

  Future<List<Discount>> list(String orgId) async {
    final res = await _c.dio.get('/discounts', queryParameters: {'org_id': orgId});
    return (res.data as List).map((d) => Discount.fromJson(d)).toList();
  }
}

final discountApiProvider = Provider<DiscountApi>(
    (ref) => DiscountApi(ref.watch(dioClientProvider)));
