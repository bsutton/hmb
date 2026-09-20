import 'package:june/june.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../dao/billing_attention_cache.dart';
import '../dashboard.dart';

/// Non-blocking dashboard data: deliberately does not use BlockingUI.
class BillingAttentionCount extends StatelessWidget {
  final BillingAttentionCache? cache;
  const BillingAttentionCount({super.key, this.cache});

  BillingAttentionCache get _cache => cache ?? BillingAttentionCache.instance;

  @override
  Widget build(BuildContext context) => JuneBuilder(
    DashboardReloaded.new,
    builder: (_) {
      _cache.requestRefresh();
      return ListenableBuilder(
        listenable: _cache,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Jobs to bill: ${_cache.entries?.length ?? '—'}'),
            if (_cache.error != null)
              const Text('Billing count unavailable — reopen to retry'),
            if (_cache.updating ||
                (_cache.entries == null && _cache.error == null))
              const Text('Updating billing…'),
          ],
        ),
      );
    },
  );
}
