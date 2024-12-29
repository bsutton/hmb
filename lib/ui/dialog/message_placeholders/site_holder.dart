import '../../../entity/site.dart';
import '../message_template_dialog.dart';
import 'place_holder.dart';
import 'site_source.dart';

class SiteHolder extends PlaceHolder<Site, Site> {
  SiteHolder(this.siteSource)
      : super(name: tagName, base: tagBase, source: siteSource);

  static String tagName = 'site';
  static String tagBase = 'site';

  final SiteSource siteSource;

  Site? site;
  @override
  Future<String> value(MessageData data) async => site?.address ?? '';

  @override
  void setValue(Site? value) => site = value;
}
