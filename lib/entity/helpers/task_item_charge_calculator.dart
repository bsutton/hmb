// import 'package:money2/money2.dart';

// import '../entity.g.dart';
// import 'labour_calculator.dart';
// import 'material_calculator.dart';

// class TaskItemChargeCalculator {
//   final TaskItem taskItem;
//   TaskItemChargeCalculator(this.taskItem);

//   MaterialCalculator getMaterialCosts(BillingType billingType) =>
//       MaterialCalculator(billingType, taskItem);

//   /// Returns the **final line total charge** for this item.
//   ///
//   /// Delegates to [MaterialCalculator] or [LabourCalculator],
//   /// both of which now apply margin at the **line level** only.
//   /// This method should always be used instead of directly
//   /// computing totals in the UI or business logic.
//   Money getTotalCharge(BillingType billingType, Money hourlyRate) {
//     switch (taskItem.itemType) {
//       case TaskItemType.materialsStock:
//       case TaskItemType.materialsBuy:
//       case TaskItemType.toolsOwn:
//       case TaskItemType.toolsBuy:
//       case TaskItemType.consumablesStock:
//       case TaskItemType.consumablesBuy:
//         final mc = MaterialCalculator(billingType, taskItem);
//         return mc.calcMaterialCharges(billingType);

//       case TaskItemType.labour:
//         return LabourCalculator(taskItem, hourlyRate).totalCharge;
//     }
//   }

//   // ---- Convenience wrappers -------------------------------------------------

//   Money calcMaterialCharges(BillingType billingType) => MaterialCalculator(
//     billingType,
//     taskItem,
//   ).calcMaterialCharges(billingType);

//   Money calcLabourCharges(Money hourlyRate) =>
//       LabourCalculator(taskItem, hourlyRate).totalCharge;
// }
