/// Independently saved sections of an existing job.
enum JobEditSection {
  summary('Summary and description'),
  parties('Parties', immediate: true),
  customer('Customer links'),
  billing('Billing'),
  site('Site'),
  internalNotes('Internal notes'),
  assumptions('Assumptions'),
  schedule('Schedule', immediate: true),
  notes('Job notes', immediate: true),
  attachments('Attachments', immediate: true),
  photos('Photos', immediate: true);

  const JobEditSection(this.title, {this.immediate = false});

  final String title;

  /// These screens manage their own records, rather than a job-field draft.
  final bool immediate;
}
