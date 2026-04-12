import 'room_editor_line.dart';
import 'room_editor_constraint_voiloation.dart';

class RoomEditorSolveResult {
  final List<RoomEditorLine> lines;
  final bool converged;
  final double maxError;
  final List<RoomEditorConstraintViolation> violations;

  const RoomEditorSolveResult({
    required this.lines,
    required this.converged,
    required this.maxError,
    required this.violations,
  });
}
