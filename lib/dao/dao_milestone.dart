import 'package:june/june.dart';

import '../entity/milestone.dart';
import 'dao.dart';

class DaoMilestone extends Dao<Milestone> {
  @override
  String get tableName => 'milestone';

  @override
  Milestone fromMap(Map<String, dynamic> map) => Milestone.fromMap(map);

  Future<List<Milestone>> getByQuoteId(int quoteId) async {
    final db = withoutTransaction();
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'quote_id = ?',
      whereArgs: [quoteId],
      orderBy: 'milestone_number ASC',
    );
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  @override
  JuneStateCreator get juneRefresher => MilestonePaymentState.new;

  Future<void> deleteByInvoiceId(int id) async {}
}

/// Used to notify the UI that the message template has changed.
class MilestonePaymentState extends JuneState {
  MilestonePaymentState();
}
