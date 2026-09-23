import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/api/chat_gpt/customer_extract_api_client.dart';

void main() {
  test(
    'job extraction preserves principal, referrer and bill-to separately',
    () {
      final result = CustomerExtractApiClient.parseExtraction({
        'customerName': 'Owners Corporation 42',
        'companyName': 'Harbour Property Management',
        'firstName': '',
        'jobParties': <String, dynamic>{
          'referringCustomer': 'Harbour Property Management',
          'referralEvidence':
              'Work order issued by Harbour Property Management',
          'billToCustomer': 'Owners Corporation 42',
          'billingEvidence': 'Invoice Owners Corporation 42',
          'contacts': [
            <String, dynamic>{
              'firstName': 'Morgan',
              'surname': 'Manager',
              'email': 'morgan@example.test',
              'phone': '0400000000',
              'customerName': 'Harbour Property Management',
              'role': 'Project Manager',
              'evidence': 'Contact Morgan for approval',
            },
            <String, dynamic>{
              'firstName': 'Taylor',
              'surname': 'Tenant',
              'role': 'Tenant',
              'evidence': 'Taylor will provide access',
            },
          ],
        },
      }, forJob: true);
      expect(result.customerName, 'Owners Corporation 42');
      expect(result.companyName, 'Harbour Property Management');
      expect(result.jobParties!.contacts, hasLength(2));
      expect(result.jobParties!.contacts.last.role, 'Tenant');
      expect(result.jobParties!.contacts.last.email, isEmpty);
      expect(result.jobParties!.billToCustomer, 'Owners Corporation 42');
      expect(
        result.jobParties!.referringCustomer,
        'Harbour Property Management',
      );
    },
  );

  test('missing billing instructions do not infer payer from referrer', () {
    final result = CustomerExtractApiClient.parseExtraction({
      'customerName': 'Owner',
      'companyName': 'Agent',
      'jobParties': <String, dynamic>{'referringCustomer': 'Agent'},
    }, forJob: true);
    expect(result.jobParties!.billToCustomer, isEmpty);
    expect(result.jobParties!.billingEvidence, isEmpty);
    expect(result.jobParties!.contacts, isEmpty);
  });

  test(
    'legacy flat responses and customer-only extraction remain supported',
    () {
      final json = <String, dynamic>{
        'companyName': 'Company',
        'customerName': 'Principal',
        'firstName': 'Pat',
        'surname': 'Smith',
      };
      expect(
        CustomerExtractApiClient.parseExtraction(json).customerName,
        'Company',
      );
      final job = CustomerExtractApiClient.parseExtraction(json, forJob: true);
      expect(job.customerName, 'Principal');
      expect(job.jobParties, isNull);
    },
  );
}
