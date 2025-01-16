import 'source.dart';

abstract class PlaceHolder<S> {
  /// [base] e.g. job
  /// [name] e.g. job.cost
  PlaceHolder({
    required this.name,
    required this.base,
    required this.source,
  });

  // factory PlaceHolder.fromName(String name) {
  //   final placeholder = placeHolders[name];
  //   if (placeholder != null) {
  //     return placeholder.call() as PlaceHolder<T>;
  //   } else {
  //     return DefaultHolder(name) as PlaceHolder<T>;
  //   }
  // }

  String name;

  /// the part of the placeholder name that is used
  /// to get an entity.
  /// e.g. job.name
  /// 'job' is the key.
  final String base;

  Source<S> source;

  /// Returns the underlying [Source] value as a formatted
  /// String.
  Future<String> value();

  // ignore: avoid_setters_without_getters
  /// The template dialog calls listen to get change events
  /// from the source of the placeholder
  // ignore: avoid_setters_without_getters
  set listen(void Function(S? onChanged, ResetFields resetFields) onChanged) {
    source.listen(onChanged);
  }
}
