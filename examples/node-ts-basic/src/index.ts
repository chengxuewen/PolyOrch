// The TS carrier (D37): source-level debugging via built entry + source maps.
// This file compiles to dist/index.js with dist/index.js.map; the generated
// launch row's `program` is that built entry and js-debug maps breakpoints
// back into the src/ files through the row's outFiles glob.
// F5 story (Task 2 depth): breakpoint in core.ts `while`, in format.ts
// `formatTotal`, and in vendor/tslib/src/tslib.ts `tag` -- the vendor lib is
// installed by npm as a file: symlink and ships PREBUILT (dist + sibling map
// committed), so the third-party frame folds back into its TS source under
// the same default outFiles glob, no OUTFILES override needed.
import { total } from "./core";
import { formatTotal } from "./format";
import { tag } from "vendor-tslib";

console.log(formatTotal(total(5)));
console.log(`node-ts-basic/${tag()}`);
