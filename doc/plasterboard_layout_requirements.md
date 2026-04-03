# Plasterboard Layout Requirements

## Purpose

This document captures the working rules for the plasterboard layout tool.
It is the reference to consult before changing:

- `lib/util/dart/plaster_geometry.dart`
- `lib/ui/tools/plasterboard/plaster_project_screen.dart`
- `lib/ui/tools/plasterboard/plaster_project_pdf.dart`
- any plasterboard layout persistence, migration, or PDF output

If code behavior conflicts with this document, treat the document as the
layout intent and update the implementation to match.

## Surface Direction

The layout tool must support an explicit sheet direction for:

- each wall
- the ceiling for each room

Direction should be modeled as a persisted setting, not just a temporary UI
choice.

Expected direction options:

- `Auto`
- `Horizontal`
- `Vertical`

`Auto` may choose the most efficient layout, but it must still obey all layout
rules in this document.

## Required Rules

These are hard requirements for the layout generator.

### 1. Minimum edge pieces

For any surface layout, do not create a start piece or end piece smaller than
`300 mm`.

This applies to:

- wall layouts
- ceiling layouts
- both layout axes

If a proposed layout direction cannot satisfy the `300 mm` minimum-piece rule,
the generator must either:

- adjust the layout pattern while preserving the rest of the rules, or
- reject that direction as invalid

It must not silently emit a weak edge strip.

### 2. Horizontal wall layouts start with a half-height sheet

When a wall is laid out horizontally:

- the first course must use a half-height sheet
- the half-height sheet is produced by cutting the board along its long axis
- this is intended to keep the first tape joint lower so it can usually be
  finished without a ladder

The generator must take that starter rule into account when calculating:

- joints
- sheet count
- waste
- coverage pattern

If an exact half-height starter would force a start or end piece under
`300 mm`, the generator must adjust the pattern without violating the
minimum-piece rule.

### 3. Portrait wall laying is only valid for full-height boards

For wall layouts, portrait/vertical laying should only be used if the chosen
board can run from floor to ceiling without a horizontal join.

If the board height is less than the wall height, portrait/vertical laying is
invalid for that wall and must be rejected.

The current generator is stricter than this for normal layout search:

- vertical is rejected for any multi-sheet wall or ceiling layout
- vertical is only allowed when a single vertically oriented sheet can cover
  the full target surface

This single-sheet exception is valid for:

- walls
- ceilings

### 4. Direction must affect the actual layout

The chosen direction is not decorative metadata. It must alter:

- the orientation used for sheet-count calculation
- the sheet coverage shown in the UI and PDF
- the cutting pattern assumptions

### 5. Layout output must be understandable

The UI and PDF must describe the resulting layout clearly. Ambiguous labels
such as bare `3 x 1` should be avoided.

### 5a. Framing metadata is part of the solver input

Support alignment is driven by framing metadata, not by sheet size alone.

The solver must resolve framing settings in this order:

- per-wall override for wall surfaces
- per-ceiling override for ceiling surfaces
- project default

The framing model must distinguish between:

- spacing: center-to-center support distance
- offset: the first support centerline offset from the surface origin
- fixing face width: the width of the support face available for fixing

Current placement rule:

- butt joints must land on the centerline of the support face

That means spacing and offset define where joint centerlines may occur. The
fixing face width must still be persisted and exposed to the user, but it does
not currently relax the centerline landing rule.

Required persisted settings:

- project defaults
  - wall stud spacing
  - wall stud offset
  - wall fixing face width
  - ceiling framing spacing
  - ceiling framing offset
  - ceiling fixing face width
- per-wall overrides
  - stud spacing
  - stud offset
  - fixing face width
- per-ceiling overrides
  - framing spacing
  - framing offset
  - fixing face width

## Additional Practical Rules

These are general drywall/plasterboard layout rules that should guide future
improvements.

### 6. Stagger joints where possible

Adjacent rows/courses should stagger joints rather than lining them up in the
same location.

This is especially important for horizontal wall laying, where the starter
pattern should help avoid stacked joints.

Layouts must reject adjacent rows or columns that place sheet joints within
`300 mm` of each other.

This stagger requirement is a hard pruning rule for generated candidates, not
just a soft scoring preference.

### 6a. Partial pieces belong at the ends of a row

When generating a row or course of sheets:

- any partial sheet must be at the start or the end of the row
- partial sheets must not appear in the middle of the row
- at most two partial sheets are allowed in a row, one at each end

This keeps the field of the wall or ceiling made from full sheets and avoids
obviously poor layouts entering the search space.

### 7. Minimize joins

When multiple valid wall layouts satisfy the rules, prefer the one with fewer
joins.

This means the generator should prefer:

- fewer horizontal joints
- fewer vertical joints
- larger continuous sheets
- fewer butt joints

even if multiple layouts use the same number of boards.

### 8. Avoid four-corner intersections

Do not create layouts that cause four sheet corners to meet at one point where
that can be avoided.

### 9. Prefer larger, more stable pieces

When multiple valid layouts satisfy the rules, prefer the one that:

- uses fewer fragile cut pieces
- avoids narrow edge strips
- keeps larger continuous sheets in the field of the wall or ceiling

### 9a. Standard cuts must be guillotine cuts

For ordinary wall and ceiling layout trimming, waste and offcuts must be
derived from end-to-end cuts only.

This means:

- a standard trim cut runs all the way across the current sheet or offcut
- the solver should model normal sheet reduction as one or two guillotine cuts
- the resulting offcuts must be rectangles produced by those cuts
- the tool must not model ordinary trimming as an internal cut-out or
  detached island

Examples:

- cutting a full sheet in half is valid
- trimming that half sheet down to final size is valid
- leaving an L-shaped offcut from ordinary rectangular trimming is not valid

Cut-outs that require detaching a piece by more than one cut are reserved for:

- odd shapes
- opening cut-outs
- other non-rectangular real-world cases

They must not be the default waste model for simple row/course trimming.

### 10. Keep the rules visible in the output

If the tool shows sheet direction, coverage, or wall references, the diagram
and the sheet layout output should stay aligned so the user can identify which
surface is being described.

The sheet-usage output should also make waste understandable by showing:

- each full parent sheet used
- the cut pieces taken from it
- reusable offcuts
- waste pieces
- dimensions for those offcuts and waste pieces where practical

## Estimating Rules

These rules drive the current takeoff calculations. Where a rule is based on a
manufacturer coverage table, keep the code aligned with the documented rate.

### 9. Screws

Use these default screw rates:

- walls: `620 screws / 100 m2`
- ceilings, horizontal lay: `820 screws / 100 m2`
- ceilings, vertical lay: `1150 screws / 100 m2`

These rates come from Gyprock Residential Installation Guide Table 3 and are
intended as planning quantities, not a substitute for project-specific framing
or engineering requirements.

### 10. Stud adhesive

For plasterboard walls, use:

- `3.5 kg / 100 m2`

This matches the Gyprock adhesive + screw wall fixing rate at `600 mm`
framing centres from Table 3 of the Gyprock Residential Installation Guide.

Do not apply this wall adhesive rate to ceilings.

### 11. Joint tape

Paper tape is the default planning assumption.

- Tape is embedded in the first coat of the jointing system.
- The estimator should derive tape quantity from the actual layout joints.
- Add vertical internal corner length to the tape total.

The current tool models tape as:

- all shared sheet-to-sheet joint lengths generated by the chosen layout
- plus the total length of inside vertical corners

### 12. Joint compound / plaster

Use a three-coat jointing assumption:

- base + second coat: `24 kg / 100 m2`
- finish coat: `8 kg / 100 m2`
- total default joint compound: `32 kg / 100 m2`

For vertical sheeting, allow `20%` more jointing material.

This follows the Gyprock Easy-Base and Easy-Finish coverage guidance together
with the Gyprock Residential Installation Guide note to allow more jointing
material for vertical sheeting.

### 13. Cornice and cornice cement

Cornice length is the wall/ceiling junction perimeter for each room where the
ceiling is plastered.

Cornice cement planning allowance:

- `12 kg` fixes approximately `100 m` of cornice
- equivalent planning rate: `0.12 kg / m`

This is a planning allowance only. Actual usage varies by cornice profile,
substrate condition, and installer practice.

### 14. Inside and outside corners

The estimator should report:

- total inside-corner length
- total outside-corner length

For now, these are derived geometrically from the room plan:

- each corner contributes one wall height
- convex interior room corners count as inside corners
- re-entrant or projecting corners count as outside corners

These totals are informational takeoff quantities and may later drive
additional accessory calculations such as angle bead or corner trim.

### 15. Sheet totals and wastage

The takeoff summary must include:

- total sheets before waste
- total sheets including waste allowance applied once at project level
- estimated wastage as board area and percentage

Per-surface wall and ceiling rows should show the raw layout sheet count only.

Estimated wastage should be derived from:

- cut waste from the chosen sheet layouts only

It must not include the extra project-level contingency sheets added by the
waste allowance.

Project-level contingency should be reported separately as an ordering
allowance, not merged into the actual layout waste figure.

It should not be calculated by applying waste separately to each surface.

## Benchmarking and Solver Comparison

Changes to the layout solver must be evaluated against a versioned benchmark
corpus. This is how the project compares solver generations without silently
rewriting history when solver inputs evolve.

### Benchmark artifacts

The current benchmark artifacts are:

- fixture corpus:
  `test/fixtures/plaster_solver/v1/benchmark_fixture_v1.dart`
- baseline thresholds:
  `test/fixtures/plaster_solver/v1/baseline_results_v1.dart`
- adapter/loader support:
  `test/util/plaster_solver_benchmark_support.dart`
- executable benchmark test:
  `test/util/plaster_geometry_benchmark_test.dart`

Each benchmark run is defined by:

- fixture schema version
- scoring version
- solver family

These versions must not be conflated.

### Fixture versioning rules

When solver inputs change:

- do not overwrite an older fixture set in place
- add a new fixture version instead, such as `v2`
- keep older fixture versions runnable where practical
- adapt older fixture versions forward through the loader if the new solver can
  still interpret them safely with defaults

Examples of changes that may require a new fixture version:

- adding per-ceiling overrides
- adding fixing-face width inputs
- changing how framing or support metadata is modeled

### Scoring versioning rules

If the meaning of a "good" solution changes, the scoring version must change.

Examples:

- adding a new penalty for poor support alignment
- increasing or reducing the importance of waste
- adding a new quality metric beyond sheet count, waste, and joint tape

Changing the scoring meaning is not the same as changing the solver.

### Current benchmark metrics

The current benchmark corpus tracks these metrics:

- total sheet count
- estimated waste percent
- total joint tape length

These metrics are used because they cover:

- ordering efficiency
- material waste
- join complexity / finishing effort

They are baseline quality checks, not yet proof of optimality.

### Running the benchmark

Run the versioned plasterboard benchmark with:

```bash
flutter test test/util/plaster_geometry_benchmark_test.dart
```

Run full analysis after benchmark-related changes with:

```bash
dart analyze
```

### Comparing solver generations

To compare two solver versions:

1. Run both solvers against the same benchmark fixture version.
2. Use the same scoring version when comparing results.
3. Compare each named scenario by:
   - sheet count
   - waste percent
   - joint tape length
4. Record changes explicitly rather than editing the old baseline to fit the
   new solver.

If the new solver improves the result consistently, update the baseline
thresholds intentionally in a new commit with explanation.

If the new solver requires materially different inputs, introduce a new fixture
version and document the adapter/defaulting strategy.

### Baseline room corpus

The current baseline corpus includes:

- square walls-only room
- square room with ceiling
- bedroom with ceiling
- living room walls-only
- hallway with ceiling
- large open room with ceiling
- notched family room with ceiling

This set is intentionally mixed:

- simple rectangles
- elongated rooms
- larger ceilings
- non-rectangular plans

Future additions should expand the corpus rather than replace it unless a new
fixture version is intentionally introduced.

## Scoring and Search

The optimizer should not minimize waste alone.

When comparing valid layouts, the search should score:

- extra sheets used
- total joint length
- butt-joint length
- cut-piece count
- high joints on walls, where taping/install effort increases
- small or fragile pieces
- fragmentation of the remaining offcuts
- walls laid vertically instead of landscape where landscape is valid

These weights should be configurable from the application settings so they can
be tuned against real installation experience.

The scoring intent is practical installability, not purely mathematical waste
minimization. A layout that uses slightly more board may still be preferable
if it:

- materially reduces jointing effort
- avoids high taping work
- reduces fragile cuts
- is simpler and faster to install on site

## Source Notes

The current estimating assumptions are based on the following references:

- Gyprock Residential Installation Guide, Table 3:
  adhesive and screw usage rates per `100 m2`, including
  `3.5 kg` adhesive and `620 / 820 / 1150` screw planning rates.
  <https://www.gyprock.com.au/-/media/gyprock/content/documents/install/residential-installation-guide/gyprock-residential-installation-guide.pdf>
- Gyprock Residential Installation Guide, Table 23:
  jointing-material quantities per `100 m2` and the note to allow `20%` more
  jointing material for vertical sheeting.
  <https://www.gyprock.com.au/-/media/gyprock/content/documents/install/residential-installation-guide/gyprock-residential-installation-guide.pdf>
- Gyprock Paper Tape:
  paper tape is embedded in the first coat and is suitable for corners.
  <https://www.gyprock.com.au/products/jointing-tapes/paper-tape>
- Gyprock Easy-Base:
  first and second coat, coverage `24 kg / 100 m2`.
  <https://www.gyprock.com.au/products/jointing-easy-base>
- Gyprock Easy-Finish:
  finishing coat, coverage `8 kg / 100 m2`.
  <https://www.gyprock.com.au/products/jointing-easy-finish>
- Gyprock Presto Cornice product data:
  `12 kg` of cornice cement fixes approximately `100 m` of cornice.
  <https://www.gyprock.com.au/-/media/gyprock/content/documents/product-data-sheet/cornice/gyprock-presto-cornice-pds.pdf>

## Future Expectations

The tool should eventually be able to explain why a direction or layout was
chosen or rejected, for example:

- rejected because it would create a `200 mm` end strip
- rejected because the horizontal starter rule could not be satisfied
- chosen because it produced fewer sheets while staying within the rules

## Notes

This document captures the current product intent from the active design
discussion. It is expected to evolve as the plasterboard estimator becomes
more detailed.
