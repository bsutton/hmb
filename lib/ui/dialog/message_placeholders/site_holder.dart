import '../../../entity/site.dart';
import 'place_holder.dart';
import 'site_source.dart';

class SiteHolder extends PlaceHolder<Site> {
  SiteHolder({required this.siteSource})
    : super(name: tagName, base: _tagBase, source: siteSource);

  // ignore: omit_obvious_property_types
  static String tagName = 'site.address';
  static const _tagBase = 'site';

  final SiteSource siteSource;

  @override
  Future<String> value() async => siteSource.value?.address ?? '';
}
