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

import 'dart:math';

import 'package:money2/money2.dart';

import '../../../entity/material_price.dart';
import '../../../entity/task_item.dart';
import '../../../util/dart/money_ex.dart';

class ReceiptLineMatchInput {
  final String description;
  final Money lineTotalExTax;
  final DateTime receiptDate;
  final int? supplierId;

  const ReceiptLineMatchInput({
    required this.description,
    required this.lineTotalExTax,
    required this.receiptDate,
    required this.supplierId,
  });
}

class ReceiptTaskItemMatcher {
  const ReceiptTaskItemMatcher._();

  static List<TaskItem> sortForLine(
    Iterable<TaskItem> candidates,
    ReceiptLineMatchInput line, {
    Set<int> preferredJobIds = const {},
    Map<int, int> jobIdByTaskItemId = const {},
  }) {
    final scored =
        [
          for (final item in candidates)
            _ScoredTaskItem(
              item: item,
              score:
                  scoreLine(item, line) +
                  _preferredJobScore(item, preferredJobIds, jobIdByTaskItemId),
            ),
        ]..sort((lhs, rhs) {
          final byScore = rhs.score.compareTo(lhs.score);
          if (byScore != 0) {
            return byScore;
          }
          return rhs.item.modifiedDate.compareTo(lhs.item.modifiedDate);
        });

    return [for (final candidate in scored) candidate.item];
  }

  static List<TaskItem> sortForReceipt(
    Iterable<TaskItem> candidates,
    Iterable<ReceiptLineMatchInput> lines,
    DateTime receiptDate, {
    Set<int> preferredJobIds = const {},
    Map<int, int> jobIdByTaskItemId = const {},
  }) {
    final lineList = lines.toList();
    final scored =
        [
          for (final item in candidates)
            _ScoredTaskItem(
              item: item,
              score:
                  (lineList.isEmpty
                      ? _scoreDate(item.modifiedDate, receiptDate)
                      : lineList
                            .map((line) => scoreLine(item, line))
                            .reduce(max)) +
                  _preferredJobScore(item, preferredJobIds, jobIdByTaskItemId),
            ),
        ]..sort((lhs, rhs) {
          final byScore = rhs.score.compareTo(lhs.score);
          if (byScore != 0) {
            return byScore;
          }
          return rhs.item.modifiedDate.compareTo(lhs.item.modifiedDate);
        });

    return [for (final candidate in scored) candidate.item];
  }

  static int scoreLine(TaskItem item, ReceiptLineMatchInput line) {
    var score = 0;

    if (line.supplierId != null && item.supplierId == line.supplierId) {
      score += 25;
    }

    score += _scoreDescription(item.description, line.description);
    score += _scoreAmount(_taskItemCost(item), line.lineTotalExTax);
    score += _scoreDate(item.modifiedDate, line.receiptDate);

    return score;
  }

  static int _preferredJobScore(
    TaskItem item,
    Set<int> preferredJobIds,
    Map<int, int> jobIdByTaskItemId,
  ) => preferredJobIds.contains(jobIdByTaskItemId[item.id]) ? 500 : 0;

  /// Converts a receipt line total into the matched item's actual price while
  /// preserving package mode and package size.
  static MaterialPrice actualPriceForLine({
    required TaskItem item,
    required Money lineTotalExTax,
    required Fixed fallbackQuantity,
  }) {
    final previous = item.actualPrice ?? item.estimatedPrice;
    final quantity = previous?.quantity ?? fallbackQuantity;
    final total = MoneyEx.fromInt(lineTotalExTax.minorUnits.toInt().abs());
    final unitCost = total.divideByFixed(quantity);
    if (previous?.mode == MaterialPriceEntryMode.packages &&
        previous?.itemsPerPackage != null) {
      return MaterialPrice.packages(
        packageCount: quantity,
        packageCost: unitCost,
        itemsPerPackage: previous!.itemsPerPackage!,
      );
    }
    return MaterialPrice.items(quantity: quantity, unitCost: unitCost);
  }

  static int _scoreDescription(String taskDescription, String lineDescription) {
    final taskText = taskDescription.toLowerCase();
    final lineText = lineDescription.toLowerCase();
    if (taskText.trim().isEmpty || lineText.trim().isEmpty) {
      return 0;
    }

    var score = 0;
    if (taskText.contains(lineText) || lineText.contains(taskText)) {
      score += 80;
    }

    final taskTokens = _tokens(taskText);
    final lineTokens = _tokens(lineText);
    if (taskTokens.isEmpty || lineTokens.isEmpty) {
      return score;
    }

    final shared = taskTokens.intersection(lineTokens).length;
    final union = taskTokens.union(lineTokens).length;
    return score + ((shared / union) * 90).round();
  }

  static int _scoreAmount(Money? taskCost, Money lineCost) {
    if (taskCost == null || lineCost.isZero) {
      return 0;
    }

    final taskMinor = taskCost.minorUnits.toInt().abs();
    final lineMinor = lineCost.minorUnits.toInt().abs();
    if (taskMinor == 0 || lineMinor == 0) {
      return 0;
    }

    final difference = (taskMinor - lineMinor).abs();
    final largest = max(taskMinor, lineMinor);
    final ratio = difference / largest;
    return (80 * max(0, 1 - ratio)).round();
  }

  static int _scoreDate(DateTime modifiedDate, DateTime receiptDate) {
    final days = modifiedDate.difference(receiptDate).inDays.abs();
    if (days == 0) {
      return 30;
    }
    if (days <= 1) {
      return 25;
    }
    if (days <= 7) {
      return 18;
    }
    if (days <= 30) {
      return 8;
    }
    return 0;
  }

  static Money? _taskItemCost(TaskItem item) =>
      (item.actualPrice ?? item.estimatedPrice)?.totalCost;

  static Set<String> _tokens(String value) => RegExp('[a-z0-9]+')
      .allMatches(value)
      .map((match) => match.group(0)!)
      .where((token) => token.length > 1)
      .toSet();
}

class _ScoredTaskItem {
  final TaskItem item;
  final int score;

  const _ScoredTaskItem({required this.item, required this.score});
}
