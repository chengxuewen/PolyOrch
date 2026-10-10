// The source-level debug carrier: this file IS the launch `program` of the
// js-debug row PolyOrch generates (package main -> src/index.js). Plain JS,
// so breakpoints set here bind directly -- no build step, no source maps.
// F5 story (Task 1 depth): breakpoint in core.js `while`, in format.js
// `formatTotal`, and in vendor/vendorlib/index.js `banner` (installed by
// npm as a node_modules symlink; the runtime path is the vendor realpath).
"use strict";
const { total } = require("./core.js");
const { formatTotal } = require("./format.js");
const { banner } = require("vendorlib");

console.log(formatTotal(total(5)));
console.log(banner("node-basic"));
