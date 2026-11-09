import 'package:flutter_test/flutter_test.dart';
import 'package:hmb/dao/dao.g.dart';
import 'package:hmb/dao/invoice_lifecycle_service.dart';
import 'package:hmb/dao/task_fixed_agreement.dart';
import 'package:hmb/entity/entity.g.dart';
import 'package:hmb/util/dart/money_ex.dart';
import 'package:money2/money2.dart';

import '../../database/management/db_utility_test_helper.dart';
import '../../util/settings_test_helper.dart';
import 'milestone_tm_fixture.dart';
import 'utility.dart' show insertMaterialItem;

void main() {
  setUpAll(prepareSettingsTest);
  setUp(() async {
    await resetSettingsForTest();
    await setupTestDb();
  });
  tearDown(tearDownTestDb);

  test('correct inherited fixed task with unbilled work to T&M', () async {
    final f = await MilestoneTmFixture.create();
    await f.invoiceMilestone(0);
    final extra = Task.forInsert(
      jobId: f.job.id,
      name: 'Additional work accidentally left as Same as job',
      description: '',
      status: TaskStatus.inProgress,
    );
    await DaoTask().insert(extra);
    final time = await f.addLabour(extra);
    await f.invoiceMilestone(1);
    expect((await f.preview()).candidates, isEmpty);
    expect((await f.preview()).blocked, isNotEmpty);

    await DaoTask().update(
      extra.copyWith(billingType: BillingType.timeAndMaterial),
    );

    final preview = await f.preview();
    expect(preview.candidates.single.key, 'time:${time.id}');
    expect(preview.candidates.single.amount, MoneyEx.dollars(176));
    final invoice = await f.invoiceKeys(['time:${time.id}']);
    expect(invoice.totalAmount, MoneyEx.dollars(176));
    expect((await f.preview()).candidates, isEmpty);
    expect(
      (await DaoQuote().getById(f.quote.id))!.totalAmount,
      MoneyEx.dollars(1000),
    );
    for (final milestone in f.milestones) {
      final saved = (await DaoMilestone().getById(milestone.id))!;
      expect(saved.invoiceId, isNotNull);
      expect(saved.paymentAmount, MoneyEx.dollars(500));
    }
  });

  test(
    'unagreed fixed material task can be corrected to actual pricing',
    () async {
      final f = await MilestoneTmFixture.create();
      final extra = Task.forInsert(
        jobId: f.job.id,
        name: 'Additional materials',
        description: '',
        status: TaskStatus.completed,
        billingType: BillingType.fixedPrice,
      );
      await DaoTask().insert(extra);
      final material = await insertMaterialItem(
        extra,
        itemType: TaskItemType.materialsBuy,
        estimatedQuantity: Fixed.one,
        estimatedUnitCost: MoneyEx.dollars(30),
        actualQuantity: Fixed.fromNum(2),
        actualUnitCost: MoneyEx.dollars(50),
      );
      await DaoTask().update(
        extra.copyWith(billingType: BillingType.timeAndMaterial),
      );
      final charge = (await f.preview()).candidates.singleWhere(
        (c) => c.key == 'item:${material.id}',
      );
      expect(charge.amount, MoneyEx.dollars(100));
      expect((await f.invoiceKeys([charge.key])).totalAmount, charge.amount);
    },
  );

  test('quoted and agreed fixed scope still cannot change to T&M', () async {
    final f = await MilestoneTmFixture.create();
    await f.addLabour(f.fixed);
    for (final invoiceMilestone in [false, true]) {
      if (invoiceMilestone) {
        await f.invoiceMilestone(0);
      }
      await expectLater(
        DaoTask().update(
          f.fixed.copyWith(billingType: BillingType.timeAndMaterial),
        ),
        throwsException,
      );
    }
    final agreed = Task.forInsert(
      jobId: f.job.id,
      name: 'Agreed addition',
      description: '',
      status: TaskStatus.inProgress,
    );
    await DaoTask().insert(agreed);
    await testDb!.transaction(
      (txn) => TaskFixedAgreement().save(
        txn,
        agreed,
        MoneyEx.dollars(200),
        'Customer agreed',
      ),
    );
    await f.addLabour(agreed);
    await expectLater(
      DaoTask().update(
        agreed.copyWith(billingType: BillingType.timeAndMaterial),
      ),
      throwsException,
    );
  });

  test(
    'worked T&M cannot be converted back to fixed or non-billable',
    () async {
      final f = await MilestoneTmFixture.create();
      final extra = await f.addVariation();
      await f.addLabour(extra);
      for (final type in [BillingType.fixedPrice, BillingType.nonBillable]) {
        await expectLater(
          DaoTask().update(extra.copyWith(billingType: type)),
          throwsException,
        );
      }
    },
  );

  for (final release in [false, true]) {
    test(
      'legacy fixed task with invoice history stays protected: $release',
      () async {
        final f = await MilestoneTmFixture.create();
        final extra = await f.addVariation();
        final time = await f.addLabour(extra);
        final invoice = await f.invoiceKeys(['time:${time.id}']);
        if (release) {
          final lifecycle = InvoiceLifecycleService();
          await lifecycle.voidInvoice(invoice.id, 'Correction');
          await lifecycle.releaseVoidedInvoice(invoice.id);
          expect((await DaoTimeEntry().getById(time.id))!.billed, isFalse);
        }
        // Legacy records may carry actual invoices on an inherited fixed task.
        // Seed that historical state without using today's billing-mode guard.
        await testDb!.update(
          'task',
          {'billing_type': null},
          where: 'id = ?',
          whereArgs: [extra.id],
        );
        final inherited = (await DaoTask().getById(extra.id))!;
        await expectLater(
          DaoTask().update(
            inherited.copyWith(billingType: BillingType.timeAndMaterial),
          ),
          throwsException,
        );
        expect(
          (await DaoInvoice().getById(invoice.id))!.totalAmount,
          MoneyEx.dollars(176),
        );
      },
    );
  }

  test(
    'actual charges are independent before and after final payment',
    () async {
      final f = await MilestoneTmFixture.create();
      final firstInvoice = await f.invoiceMilestone(0);
      final extra = await f.addVariation();
      final time = await f.addLabour(extra);
      final before = await f.preview();
      expect(
        before.candidates.map((c) => c.key),
        unorderedEquals([
          'milestone:${f.milestones.last.id}',
          'time:${time.id}',
        ]),
      );
      final finalInvoice = await f.invoiceMilestone(1);
      final after = await f.preview();
      expect(after.candidates.single.key, 'time:${time.id}');
      expect(after.candidates.single.amount, MoneyEx.dollars(176));
      expect((await DaoTimeEntry().getById(time.id))!.billed, isFalse);
      final tmInvoice = await f.invoiceKeys(['time:${time.id}']);
      expect(tmInvoice.totalAmount, MoneyEx.dollars(176));
      expect((await f.preview()).candidates, isEmpty);
      for (var i = 0; i < 2; i++) {
        final stored = (await DaoMilestone().getById(f.milestones[i].id))!;
        expect(stored.paymentAmount, MoneyEx.dollars(500));
        expect(stored.invoiceId, [firstInvoice.id, finalInvoice.id][i]);
      }
    },
  );

  test(
    'multiple variations, partial selection and new work retain sources',
    () async {
      final f = await MilestoneTmFixture.create();
      await f.invoiceMilestone(0);
      final first = await f.addVariation('First variation');
      final second = await f.addVariation('Second variation');
      final firstTime = await f.addLabour(first);
      final secondTime = await f.addLabour(second, hours: 1);
      final material = await insertMaterialItem(
        second,
        itemType: TaskItemType.materialsBuy,
        description: 'Additional materials',
        actualQuantity: Fixed.fromNum(2),
        actualUnitCost: MoneyEx.dollars(50),
        margin: Percentage.ten,
      );
      await f.invoiceMilestone(1);
      final firstInvoice = await f.invoiceKeys(['time:${firstTime.id}']);
      expect(firstInvoice.totalAmount, MoneyEx.dollars(176));
      var preview = await f.preview();
      expect(
        preview.candidates.map((c) => c.key),
        unorderedEquals(['time:${secondTime.id}', 'item:${material.id}']),
      );
      final materialCharge = preview.candidates.singleWhere(
        (c) => c.kind == 'item',
      );
      expect(
        materialCharge.amount,
        material.calcMaterialCost(BillingType.timeAndMaterial).lineChargeTotal,
      );
      expect(materialCharge.amount, greaterThan(MoneyEx.dollars(100)));
      final newTime = await f.addLabour(first, hours: 1);
      preview = await f.preview();
      expect(
        preview.candidates.map((c) => c.key),
        contains('time:${newTime.id}'),
      );
      expect(
        preview.candidates.map((c) => c.key),
        isNot(contains('time:${firstTime.id}')),
      );
      final invoice = await f.invoiceKeys(preview.candidates.map((c) => c.key));
      expect(invoice.totalAmount, MoneyEx.dollars(176) + materialCharge.amount);
      expect((await DaoTaskItem().getById(material.id))!.billed, isTrue);
      expect((await f.preview()).candidates, isEmpty);
      expect((await f.preview()).candidates, isEmpty);
    },
  );

  test('fixed-only delivery costs never become additional charges', () async {
    final f = await MilestoneTmFixture.create();
    await f.addLabour(f.fixed);
    await insertMaterialItem(
      f.fixed,
      itemType: TaskItemType.materialsBuy,
      actualQuantity: Fixed.one,
      actualUnitCost: MoneyEx.dollars(50),
    );
    expect(
      (await f.preview()).candidates.map((c) => c.kind),
      everyElement('milestone'),
    );
    await f.invoiceMilestone(0);
    await f.invoiceMilestone(1);
    expect((await f.preview()).candidates, isEmpty);
    await expectLater(f.invoiceMilestone(1), throwsException);
    expect(await DaoInvoice().getByJobId(f.job.id), hasLength(2));
  });

  for (final deleteDraft in [true, false]) {
    test(
      'T&M charge release follows invoice lifecycle: draft=$deleteDraft',
      () async {
        final f = await MilestoneTmFixture.create();
        await f.invoiceMilestone(0);
        final extra = await f.addVariation();
        final time = await f.addLabour(extra);
        await f.invoiceMilestone(1);
        final invoice = await f.invoiceKeys(['time:${time.id}']);
        final lifecycle = InvoiceLifecycleService();
        if (deleteDraft) {
          await lifecycle.deleteDraft(invoice.id);
        } else {
          invoice.sent = true;
          await DaoInvoice().update(invoice);
          await lifecycle.voidInvoice(invoice.id, 'Customer correction');
          expect((await f.preview()).candidates, isEmpty);
          await lifecycle.releaseVoidedInvoice(invoice.id);
        }
        expect((await f.preview()).candidates.single.key, 'time:${time.id}');
        final replacement = await f.invoiceKeys(['time:${time.id}']);
        expect(replacement.totalAmount, MoneyEx.dollars(176));
        expect((await f.preview()).candidates, isEmpty);
        expect(
          (await DaoQuote().getById(f.quote.id))!.totalAmount,
          MoneyEx.dollars(1000),
        );
      },
    );
  }
}
