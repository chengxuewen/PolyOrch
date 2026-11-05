# Reuse-First: Supplier Responsibilities (PolyOrch projection)

> Projection of the reuse-first charter (workspace root: `docs/governance/reuse-first-charter.md`; ledger: parent C60).
> Self-contained: readable in a standalone PolyOrch clone.

## The platform is the paved road

PolyOrch is this workspace's internal platform, and the face families are its paved road: the right way must also be the easiest way. Consumers adjudicate "where does this live" before writing a capability twice; when a face exists here, consumer-side hand-written equivalents are out of bounds. This document states what that obligates on the supplier side.

## Face inventory (pointer, not copy)

- Authoritative shipped-function inventory: [`docs/modules/05-surface-inventory.md`](../modules/05-surface-inventory.md) — one row per public `polyorch_*` function. Note the two numbers are different measurements: the document is the curated index, the grep below is the live source count (82 as of 2026-11-05); if they drift apart, reconcile the index — the drift is itself a signal.
- Face families relevant to reuse adjudication:
  - debug faces (native / node / python / rust) — `cmake/PolyOrchVSCodeDebugHelpers.cmake`
  - run/register faces — `polyorch_example_run`, `polyorch_python_run`, node and rust families
  - third-party recipe faces — `polyorch_thirdparty_recipe` and siblings
  - pixi environment faces — the `polyorch_pixi_*` family
- The inventory must stay listable in one grep (`grep -rh '^function(polyorch' cmake/*.cmake`) — that command is the pre-flight consumers run before claiming absence. If listing the inventory ever needs more than one line, that is a supplier bug.

## Intake: when a consumer need arrives

1. Check the inventory. If a face covers it — point the consumer at it; done.
2. Close but not covering: extend the existing face (parameters over new functions), with a test leg in `tests/`.
3. Genuinely new: propose a new face in the same family — same managed-region contract, same marker discipline (`__POLYORCH_GENERATED__`), plus a test leg. A new language (e.g. the c# face ruled 2026-11-05) means a new face here, not a consumer-side exception.
4. Record the decision (PLAN or D-entry): faces are decisions, not conveniences.

## Adding a face — the standing contract

- One writer per managed region; per-tree slices so multiple configuring trees never erase each other's rows (in flight: examples-ide-unification ruling 4).
- User-owned rows are first-class: above the marker, never rewritten.
- Every face ships with a test leg; generated rows are exercised, not assumed.

## Guardrails (the supplier side of wrong-abstraction economics)

- Do not generalize a face for a single consumer's convenience — that is the wrong-abstraction bug in supplier clothing. Second consumer, or second demonstrated need, then generalize. Rule of Three applies on this side too.
- Faces stay declarative at the call site: one function call in the consumer's CMake; everything else is generated here.
- Knowledge duplication ≠ implementation unification: two consumers' similar-looking needs may be different domains; when in doubt, keep two faces and document why.
