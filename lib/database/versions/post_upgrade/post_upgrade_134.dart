/*
 Copyright © OnePub IP Pty Ltd. S. Brett Sutton. All Rights Reserved.

 Note: This software is licensed under the GNU General Public License,
         with the following exceptions:
   • Permitted for internal use within your own business or organization only.
   • Any external distribution, resale, or incorporation into products 
      for third parties is strictly prohibited.

 See the full license on GitHub:
 https://github.com/bsutton/hmb/blob/main/LICENSE
*/

import 'package:sqflite_common/sqlite_api.dart';

import '../../../dao/dao.g.dart';
import '../../../entity/entity.g.dart';
import '../../../util/flutter/rich_text_helper.dart';

/// Is run after the v134.sql upgrade script is run.
/// Convert all rich text fields to plain text.
Future<void> postv134Upgrade(Database db) async {
  await db.transaction((transaction) async {
    final system = await DaoSystem().get(transaction);

    final removed = system.richTextRemoved;

    final daoQuote = DaoQuote();
    final daoJob = DaoJob();

    switch (removed) {
      case RichTextRemoved.notYet:
        {
          final jobs = await daoJob.getAll(transaction: transaction);

          for (final job in jobs) {
            job
              ..assumption = RichTextHelper.toPlainText(job.assumption)
              ..description = RichTextHelper.toPlainText(job.description);
            await daoJob.update(job, transaction);
          }
          await DaoSystem().update(
            system.copyWith(richTextRemoved: RichTextRemoved.job),
            transaction,
          );
        }
        continue job;

      job:
      case RichTextRemoved.job:
        {
          final quotes = await daoQuote.getAll(transaction: transaction);
          for (final quote in quotes) {
            quote.assumption = RichTextHelper.toPlainText(quote.assumption);
            await daoQuote.update(quote, transaction);
          }
          await DaoSystem().update(
            system.copyWith(richTextRemoved: RichTextRemoved.quote),
            transaction,
          );
        }
        continue quote;
      quote:
      case RichTextRemoved.quote:
        {
          // no action requried.
        }
    }
  });
}
