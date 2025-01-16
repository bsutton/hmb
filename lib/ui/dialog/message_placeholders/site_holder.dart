import '../../../entity/site.dart';
import 'place_holder.dart';
import 'site_source.dart';

class SiteHolder extends PlaceHolder< Site> {
  SiteHolder({required this.siteSource})
      : super(name: tagName, base: tagBase, source: siteSource);

  static String tagName = 'site.address';
  static String tagBase = 'site';

  final SiteSource siteSource;

  @override
  Future<String> value() async => siteSource.value?.address ?? '';
}
