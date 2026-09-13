import '../../core/network/api_client.dart';
import '../../core/network/endpoints.dart';
import '../models/models.dart';

/// Billetera, canjes, regalos y beneficios de marca.
class MedalsRepository {
  MedalsRepository(this._api);
  final ApiClient _api;

  Future<MedalWalletState> wallet() async {
    final res = await _api.get(Endpoints.meMedals,
        parse: (d) => MedalWalletState.fromJson((d as Map).cast<String, dynamic>()));
    return res.data;
  }

  Future<Medals> exchange({required String from, int quantity = 5}) async {
    final res = await _api.post(Endpoints.medalsExchange,
        body: {'from': from, 'quantity': quantity},
        parse: (d) => Medals.fromJson(((d as Map)['wallet'] as Map).cast<String, dynamic>()));
    return res.data;
  }

  Future<GiftState> gifts() async {
    final res = await _api.get(Endpoints.meGifts,
        parse: (d) => GiftState.fromJson((d as Map).cast<String, dynamic>()));
    return res.data;
  }

  Future<void> sendGifts(List<({String userId, int amount})> recipients) {
    return _api.post(Endpoints.meGifts, body: {
      'recipients': recipients.map((r) => {'userId': r.userId, 'amount': r.amount}).toList(),
    });
  }

  Future<List<Benefit>> benefits() async {
    final res = await _api.get(Endpoints.benefits,
        parse: (d) => (d as List).map((e) => Benefit.fromJson((e as Map).cast<String, dynamic>())).toList());
    return res.data;
  }

  Future<({String couponCode, String benefit})> redeem(String benefitId) async {
    final res = await _api.post(Endpoints.benefitRedeem(benefitId), parse: (d) => d);
    final m = (res.data as Map).cast<String, dynamic>();
    return (couponCode: (m['couponCode'] ?? '') as String, benefit: (m['benefit'] ?? '') as String);
  }
}
