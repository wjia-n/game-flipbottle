import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flipbottle/services/iap_service.dart';

void main() {
  test('iOS maps to the single Gold Star product', () {
    expect(FlipStore.productIdsFor(TargetPlatform.iOS), {'flipbottlestar'});
    expect(FlipStore.starId, 'flipbottlestar');
  });
  test('Android maps to coffee + chocolate', () {
    expect(FlipStore.productIdsFor(TargetPlatform.android),
        {'flipbottlecoffee', 'flipbottlechocolate'});
  });
  test('iOS and Android product sets do not overlap', () {
    expect(FlipStore.productIdsFor(TargetPlatform.iOS)
        .intersection(FlipStore.productIdsFor(TargetPlatform.android)), isEmpty);
  });
}
