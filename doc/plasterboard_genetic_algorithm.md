# Plasterboard Genetic Algorithm Lab

## Goal

The genetic algorithm is an experimental optimiser for the plasterboard layout
lab. It is intended to explore layout variants that the deterministic beam
search may not reach, with waste percentage as the primary metric.

The first implementation is deliberately isolated from production layout code.
It lives under `tool/` and is wired into the standalone algorithm lab.

## Genome

The smallest crossover unit is a run.

```text
SurfaceGenome
  surface identity
  runs[]

RunGenome
  axis
  depth class
  material index within the depth class
  depth
  sheets[]

SheetGene
  length along the run
```

A run is one coherent laying strip or course. All sheets in a run share:

- the same run axis
- the same material depth class
- the same run depth

The run material index is local to the selected depth class. This prevents
generation or breeding from creating a mixed-depth run, such as combining
1200 mm and 1350 mm boards in the same course.

The genome keeps material selection at run level, not sheet level. During
decode the repair step coerces all runs on a surface to one compatible material
family because the existing `PlasterSurfaceLayout` model carries one material
per layout. The decoded output is one complete wall or ceiling layout, with
multiple runs represented as placements inside that surface.

## Coordinates

The genome does not store `x`/`y` offsets.

Offsets are derived during decoding:

- run order determines the cross-axis offset
- sheet order determines the main-axis offset
- prior run depths and sheet lengths produce placement coordinates

This keeps DNA small and makes the list order meaningful.

## Breeding

Breeding happens at run boundaries:

- select a parent surface from each parent
- choose whole runs from either parent
- repair the child surface so run depths cover the target surface exactly
- repair each run so sheet lengths cover the target length exactly

Mutation changes a whole run or a sheet length inside a run:

- replace a run with a fresh constrained-random run
- change the run material within the run depth class
- resize a sheet length within the selected material capacity
- regenerate a run if repair cannot make it valid

The GA does not split a run during crossover. A run may mutate internally, but
it remains the smallest divisible chromosome.

## Fitness

The current lab fitness prioritises:

1. no under-purchased board area
2. lower waste percentage
3. fewer purchased sheets
4. lower joint tape length
5. fewer invalid/fragile edge pieces
6. shorter runtime as a secondary reporting metric

The decoded candidate is converted into normal `PlasterSurfaceLayout` objects
so the existing takeoff and explorer paths can score and display it.

The under-purchase check is important because `calculateTakeoff` clamps
negative waste to zero. Without this penalty, an invalid candidate could appear
to have perfect waste.

## Performance Notes

The first version uses readable Dart objects because it is an experiment and
the fixture corpus is small. If population evaluation becomes the bottleneck,
the intended next step is a packed representation:

```text
Int32List run records:
  surface index, axis, depth class, material index, depth,
  sheet start, sheet count

Int32List sheet records:
  length
```

That packed form would support double-buffered generations and cheaper isolate
message passing. Isolates are not used in the initial implementation because
the overhead is likely larger than the work for the current fixture set.
