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

### 4. Direction must affect the actual layout

The chosen direction is not decorative metadata. It must alter:

- the orientation used for sheet-count calculation
- the sheet coverage shown in the UI and PDF
- the cutting pattern assumptions

### 5. Layout output must be understandable

The UI and PDF must describe the resulting layout clearly. Ambiguous labels
such as bare `3 x 1` should be avoided.

## Additional Practical Rules

These are general drywall/plasterboard layout rules that should guide future
improvements.

### 6. Stagger joints where possible

Adjacent rows/courses should stagger joints rather than lining them up in the
same location.

This is especially important for horizontal wall laying, where the starter
pattern should help avoid stacked joints.

### 7. Minimize joins

When multiple valid wall layouts satisfy the rules, prefer the one with fewer
joins.

This means the generator should prefer:

- fewer horizontal joints
- fewer vertical joints
- larger continuous sheets

even if multiple layouts use the same number of boards.

### 8. Avoid four-corner intersections

Do not create layouts that cause four sheet corners to meet at one point where
that can be avoided.

### 9. Prefer larger, more stable pieces

When multiple valid layouts satisfy the rules, prefer the one that:

- uses fewer fragile cut pieces
- avoids narrow edge strips
- keeps larger continuous sheets in the field of the wall or ceiling

### 10. Keep the rules visible in the output

If the tool shows sheet direction, coverage, or wall references, the diagram
and the sheet layout output should stay aligned so the user can identify which
surface is being described.

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

## Scoring and Search

The optimizer should not minimize waste alone.

When comparing valid layouts, the search should score:

- extra sheets used
- total joint length
- cut-piece count
- high joints on walls, where taping/install effort increases
- small or fragile pieces
- fragmentation of the remaining offcuts

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
