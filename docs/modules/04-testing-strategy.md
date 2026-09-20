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

## Related documents

- [`./03-error-model.md`](./03-error-model.md)
- [`../architecture.md`](../architecture.md)
