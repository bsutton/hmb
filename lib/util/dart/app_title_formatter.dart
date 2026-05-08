import '../../entity/job.dart';

String formatAppTitle(String pageTitle, {Job? activeJob}) {
  if (activeJob == null) {
    return pageTitle;
  }
  return '$pageTitle [#${activeJob.id}]';
}
