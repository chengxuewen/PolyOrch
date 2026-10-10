"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.tag = tag;
// The vendored "third-party" TS library, shipped PREBUILT (dist + map are
// committed, the node-web checked-in-dist precedent). Breakpoint story:
// runtime loads dist/tslib.js (realpath via npm's file: symlink), the
// sibling map maps js-debug back to src/tslib.ts -- which the default
// outFiles glob `${pkg}/**/*.js` already covers.
function tag() {
    return "vendor-tslib: OK";
}
//# sourceMappingURL=tslib.js.map