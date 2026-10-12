import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../api/product_catalog/product_catalog.dart';
import '../widgets/hmb_button.dart';
import '../widgets/layout/hmb_form_section.dart';
import '../widgets/layout/surface.dart';

/// Original vector drawings, not retailer product photography.
class ProductPicture extends StatelessWidget {
  const ProductPicture({required this.product, super.key});
  final CatalogProduct product;

  String get _drawing => switch (product.illustration) {
    ProductIllustration.paint =>
      '''
<path d="M34 30 Q60 -3 86 30" fill="none"/>
<path d="M30 27 H90 L84 82 H36 Z" fill="#a99bcc"/>
<ellipse cx="60" cy="27" rx="30" ry="7" fill="#fff"/>
<path d="M36 45 H85 V69 H36 Z" fill="#faf8ec"/>
''',
    ProductIllustration.timber =>
      '''
<path d="M15 50 L80 18 L105 34 L40 72 Z" fill="#cea46f"/>
<path d="M15 50 V66 L40 82 V72 M40 82 L105 44 V34" fill="#b6844c"/>
<path d="M30 50 L81 27 M42 58 L92 32" fill="none"/>
''',
    ProductIllustration.screw =>
      '''
<path d="M32 19 L87 74 M26 25 L38 13 M77 82 L94 65"
fill="none" stroke-width="9"/>
<path d="M39 36 L48 27 M47 44 L56 35 M55 52 L64 43
M63 60 L72 51 M71 68 L80 59" stroke="#a99bcc"/>
''',
    ProductIllustration.sealant =>
      '''
<path d="M45 39 H75 V83 H45 Z" fill="#a99bcc"/>
<path d="M48 39 L64 12 L72 39" fill="#fff"/>
<path d="M46 53 H74 V69 H46" fill="#faf8ec"/>
''',
    ProductIllustration.brush =>
      '''
<path d="M39 12 H81 V42 H39 Z" fill="#cea46f"/>
<path d="M39 42 H81 V53 H39 Z" fill="#a99bcc"/>
<path d="M49 53 H71 L65 84 H55 Z" fill="#b6844c"/>
<path d="M48 14 V35 M59 14 V35 M71 14 V35" fill="none"/>
''',
    ProductIllustration.board =>
      '''
<path d="M17 39 L78 12 L104 56 L43 84 Z" fill="#faf8ec"/>
<path d="M17 39 V45 L43 90 L104 62 V56 M43 84 V90" fill="none"/>
''',
  };

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Sample illustration of ${product.name}',
    image: true,
    child: SvgPicture.string(
      '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 96">
<rect width="120" height="96" rx="12" fill="#e7e3f0"/>
<g stroke="#393345" stroke-width="3" stroke-linejoin="round">
$_drawing
</g></svg>
''',
      width: 120,
      height: 96,
    ),
  );
}

class ProductCard extends StatelessWidget {
  const ProductCard({
    required this.product,
    required this.onDetails,
    super.key,
  });
  final CatalogProduct product;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) => Surface(
    child: HMBFormSection(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: ProductPicture(product: product),
        ),
        Text(product.name, style: Theme.of(context).textTheme.titleMedium),
        Text(product.priceLabel),
        Text(product.details),
        HMBButtonSecondary(
          label: 'Details and stores',
          onPressed: onDetails,
          hint: 'Review ${product.name} and choose a demo store',
        ),
      ],
    ),
  );
}
