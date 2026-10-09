import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/flip_themes.dart';
import 'ui_kit.dart';

/// Flip Bottle PRO: Free-vs-Pro comparison, real purchase, restore, tip jar.
/// Prices come from the store — never hardcoded, never placeholders.
/// When products aren't configured in Play Console yet, the screen says so
/// honestly instead of showing fake buy buttons.
class ProScreen extends StatefulWidget {
  final FlipAudio audio;
  final FlipSettings settings;
  final FlipStore store;

  const ProScreen({
    super.key,
    required this.audio,
    required this.settings,
    required this.store,
  });

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ComparisonRow {
  final String feature;
  final String free;
  final String pro;
  const _ComparisonRow(this.feature, this.free, this.pro);
}

const _rows = [
  _ComparisonRow('Venue themes', '8 venues', 'All 12 venues'),
  _ComparisonRow('Bottle styles', '5 bottles', 'All 8 bottles'),
  _ComparisonRow('Table materials', '5 tables', 'All 8 tables'),
  _ComparisonRow('Custom theme studio', '🔒 Locked', '✓ Unlocked'),
  _ComparisonRow('Score Attack mode', '🔒 Locked', '✓ Unlocked'),
  _ComparisonRow('Classic + Endless', '✓ Included', '✓ Included'),
  _ComparisonRow('Ads', 'None, ever', 'None, ever'),
];

class _ProScreenState extends State<ProScreen> {
  FlipThemeDef get _t => flipThemeById(
        widget.settings.themeId,
        custom: widget.settings.customTheme,
      );

  @override
  void initState() {
    super.initState();
    widget.store.proPurchased.addListener(_onPro);
    widget.store.lastThanks.addListener(_onThanks);
  }

  void _onPro() {
    if (widget.store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      widget.audio.win();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PRO unlocked — enjoy everything!',
              style: FlipUi.body(15, _t, color: Colors.white)),
          backgroundColor: _t.accent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.store.proPurchased.value = false;
    }
  }

  void _onThanks() {
    final msg = widget.store.lastThanks.value;
    if (msg == null || !mounted) return;
    widget.audio.win();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: FlipUi.body(15, _t, color: Colors.white)),
        backgroundColor: _t.accent,
        behavior: SnackBarBehavior.floating,
      ),
    );
    widget.store.lastThanks.value = null;
  }

  @override
  void dispose() {
    widget.store.proPurchased.removeListener(_onPro);
    widget.store.lastThanks.removeListener(_onThanks);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    final store = widget.store;
    return Scaffold(
      body: Container(
        decoration: FlipUi.backdrop(t),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
                child: Row(
                  children: [
                    FlipUi.iconButton(t,
                        icon: Icons.arrow_back,
                        tooltip: 'Back',
                        onTap: () {
                          widget.audio.click();
                          Navigator.of(context).pop();
                        }),
                    const SizedBox(width: 12),
                    Text('Flip Bottle PRO',
                        style: FlipUi.display(26, t)),
                  ],
                ),
              ),
              Expanded(
                child: ListenableBuilder(
                  listenable: s,
                  builder: (_, _) => SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Column(
                      children: [
                        _comparisonCard(t, s.isPro),
                        const SizedBox(height: 16),
                        _buyCard(t, s, store),
                        const SizedBox(height: 16),
                        _tipsCard(t, store),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _comparisonCard(FlipThemeDef t, bool isPro) {
    return FlipUi.card(t,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Container()),
                SizedBox(
                    width: 86,
                    child: Text('FREE',
                        textAlign: TextAlign.center,
                        style: FlipUi.label(12, t))),
                SizedBox(
                    width: 86,
                    child: Text('PRO',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            color: t.accent))),
              ],
            ),
            const Divider(),
            ..._rows.map((r) => Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text(r.feature,
                              style: FlipUi.body(14, t))),
                      SizedBox(
                          width: 86,
                          child: Text(r.free,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12, color: t.muted))),
                      SizedBox(
                          width: 86,
                          child: Text(r.pro,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: t.accent))),
                    ],
                  ),
                )),
            if (isPro)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: t.accent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('✓ PRO ACTIVE',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900)),
              ),
          ],
        ));
  }

  Widget _buyCard(FlipThemeDef t, FlipSettings s, FlipStore store) {
    return FlipUi.card(t,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Go PRO', style: FlipUi.display(22, t)),
            const SizedBox(height: 6),
            Text(
              'One-time unlock. Yours forever, on every device.',
              style: FlipUi.body(13, t, color: t.muted),
            ),
            const SizedBox(height: 12),
            if (s.isPro)
              Text('You already own PRO — thank you! 💛',
                  style: FlipUi.body(15, t)),
            if (!s.isPro && !store.storeReady)
              _unconfigured(t, store),
            if (!s.isPro && store.storeReady)
              _buyButton(t, s, store),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                widget.audio.click();
                store.restore();
              },
              child: Center(
                child: Text('Restore purchases',
                    style: TextStyle(
                        color: t.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        decoration: TextDecoration.underline)),
              ),
            ),
            ValueListenableBuilder<String?>(
              valueListenable: store.purchaseError,
              builder: (_, err, __) => err == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(err,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 13)),
                    ),
            ),
          ],
        ));
  }

  Widget _unconfigured(FlipThemeDef t, FlipStore store) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.muted.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        store.error ??
            'PRO purchases will be available after the store setup is complete. The game is fully playable meanwhile!',
        textAlign: TextAlign.center,
        style: FlipUi.body(13, t, color: t.muted),
      ),
    );
  }

  Widget _buyButton(FlipThemeDef t, FlipSettings s, FlipStore store) {
    final p = store.proProduct;
    return ValueListenableBuilder<bool>(
      valueListenable: store.purchaseInProgress,
      builder: (_, busy, __) => FlipUi.chunkyButton(
        t: t,
        text: busy
            ? 'WORKING…'
            : (p == null ? 'BUY PRO' : 'BUY PRO • ${p.price}'),
        icon: Icons.star,
        onTap: busy ? () {} : () => store.buyPro(),
      ),
    );
  }

  Widget _tipsCard(FlipThemeDef t, FlipStore store) {
    return FlipUi.card(t,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tip jar ☕', style: FlipUi.display(22, t)),
            const SizedBox(height: 6),
            Text(
              'Flip Bottle is 100% free. If it made you smile, a tip keeps the bottles flipping!',
              style: FlipUi.body(13, t, color: t.muted),
            ),
            const SizedBox(height: 12),
            if (!store.storeReady)
              _unconfigured(t, store)
            else
              Row(
                children: [
                  Expanded(child: _tipButton(t, store, store.coffeeProduct, '☕', 'Coffee')),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _tipButton(t, store, store.chocolateProduct, '🍫', 'Chocolate')),
                ],
              ),
          ],
        ));
  }

  Widget _tipButton(FlipThemeDef t, FlipStore store, ProductDetails? p,
      String emoji, String label) {
    if (p == null) {
      return FlipUi.chunkyButton(
          t: t, text: '$emoji $label', fontSize: 14, onTap: () {});
    }
    return ValueListenableBuilder<bool>(
      valueListenable: store.purchaseInProgress,
      builder: (_, busy, __) => FlipUi.chunkyButton(
        t: t,
        text: '$emoji ${p.price}',
        fontSize: 14,
        color: t.muted,
        onTap: busy ? () {} : () => store.buyTip(p),
      ),
    );
  }
}
