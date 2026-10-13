import 'dart:async';

import 'package:flutter/foundation.dart';

import 'product_catalog.dart';

/// Debounces text, invalidates in-flight results immediately on every edit,
/// and never writes into the owning task form.
class ProductSearchController extends ChangeNotifier {
  ProductSearchController(
    this.catalog, {
    this.delay = const Duration(milliseconds: 350),
  });

  final ProductCatalog catalog;
  final Duration delay;
  Timer? _timer;
  var _revision = 0;
  var _disposed = false;
  var query = '';
  var busy = false;
  String? error;
  List<CatalogProduct> results = [];

  void search(String text, {bool immediate = false}) {
    _timer?.cancel();
    final revision = ++_revision;
    query = text.trim();
    results = [];
    error = null;
    busy = query.length >= 2;
    notifyListeners();
    if (!busy) {
      return;
    }
    if (immediate) {
      unawaited(_run(query, revision));
    } else {
      _timer = Timer(delay, () => unawaited(_run(query, revision)));
    }
  }

  Future<void> _run(String text, int revision) async {
    try {
      final found = await catalog.search(text);
      if (!_disposed && revision == _revision) {
        results = List.unmodifiable(found);
      }
    } catch (_) {
      if (!_disposed && revision == _revision) {
        error = 'Could not search products. Try again.';
      }
    } finally {
      if (!_disposed && revision == _revision) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _timer?.cancel();
    super.dispose();
  }
}
