import 'package:june/june.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../dao/billing_attention_cache.dart';
import '../../../widgets/hmb_tooltip.dart';
import '../dashboard.dart';

/// Non-blocking dashboard data: deliberately does not use BlockingUI.
class BillingAttentionCount extends StatelessWidget {
  final BillingAttentionCache? cache;
  const BillingAttentionCount({super.key, this.cache});

  BillingAttentionCache get _cache => cache ?? BillingAttentionCache.instance;

  String get _count {
    if (_cache.initializing) {
      return '…';
    }
    return _cache.entries?.length.toString() ??
        (_cache.error == null ? '…' : '—');
  }

  @override
  Widget build(BuildContext context) => JuneBuilder(
    DashboardReloaded.new,
    builder: (_) {
      _cache.requestRefresh();
      return ListenableBuilder(
        listenable: _cache,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Jobs to bill: $_count'),
            if (_cache.error != null ||
                _cache.checkFailed ||
                _cache.workerFailed)
              const HMBTooltip(
                hint: 'Billing check failed; retrying in the background.',
                child: Icon(Icons.warning_amber_rounded, size: 14),
              )
            else if (_cache.updating && _cache.entries != null)
              const HMBTooltip(
                hint: 'Updating billing count',
                child: Icon(Icons.sync, size: 14),
              ),
          ],
        ),
      );
    },
  );
}
