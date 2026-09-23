# Testing Strategy

> Part of the [module reference](./00-overview.md).


| Layer | What it proves | Vehicle |
|---|---|---|
| 1 | every contract clause is enforceable | one **deliberately violating fixture** per clause; assert `doctor` fails and names the right clause |
| 2 | each bridge behaves | one minimal fixture per bridge; assert scanned target names and count, artifact paths, `_bin` presence |
| 3 | the tree still builds end to end | a full build plus a green `doctor` on the `DEVSYS/xmake` prototype (8 subprojects, 5 bridges, existing build logs) |
| 4 | the debug surface is real | parse the generated `launch.json` / `settings.json`; assert every `program` points at a file that exists |
| 5 | version consistency | assert the effective addon version equals the declared version |

Layer 4 exists because a hardcoded interpreter path in the prototype's `launch.json` is a defect that a test should have caught.

Honest boundary: the acceptance bar ("replaces the daily entry point") **cannot be automated**. The five layers prove the tool is correct; the last step is a human judgement made over time.

## Dual-route testing (2026-09-23)

The rust face has two toolchain routes (`polyorch_rust_setup(FROM system|pixi)`),
and the suite proves both as two BUILD TREES of the same source tree --
ctest cache and `POLYORCH_RUST_ROUTE` are per-build-dir state, so the two
lines never share a configure:

```bash
cmake -S . -B build-system -DPolyOrch_BUILD_TESTS=ON -DPolyOrch_TEST_E2E=ON
cmake -S . -B build-pixi   -DPolyOrch_BUILD_TESTS=ON -DPolyOrch_TEST_E2E=ON \
                          -DPolyOrch_TEST_RUST_FROM=pixi
# per-tree umbrellas (IDE target UIs, hyphen names -- :: is illegal in targets):
cmake --build build-system --target polyorch-tests-system   # ctest -L system
cmake --build build-pixi   --target polyorch-tests-pixi     # ctest -L pixi
```

Route labels derive from the case `# requires:` token (`system-rust` ->
`system`; the `pixi` family -> `pixi`); legs without a gate are route-neutral
and run in both trees. In a system tree the pixi legs SKIP by contract and
vice versa -- a skip is the expected cross-tree shape, not a failure.
`tests/matrix.sh` pins the pixi cell (skip-note when no pixi tool exists);
`t-rust-route-pixi` is the connectivity keeper (its fixture materializes the
env itself and fails LOUDLY on a cold network, by design).

## Related documents

- [`./03-error-model.md`](./03-error-model.md)
- [`../architecture.md`](../architecture.md)
