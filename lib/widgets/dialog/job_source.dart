class JobSource extends Source<Job> {
  final CustomerSource customerSource;

  JobSource({required this.customerSource}) : super(name: 'job') {
    customerSource.onChanged = (customer) {
      // Reset job value when customer changes
      setValue(null);
    };
  }

  @override
  Widget field(MessageData data) {
    return HMBDroplist<Job>(
      title: 'Job',
      selectedItem: () async => value,
      items: (filter) async {
        if (customerSource.value != null) {
          return DaoJob().getByCustomerId(customerSource.value!.id, filter);
        } else {
          return [];
        }
      },
      format: (job) => job.summary,
      onChanged: (job) {
        setValue(job);
      },
    );
  }
}
