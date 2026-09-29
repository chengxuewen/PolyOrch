// The web-frontend consumption shape, run through node: import the
// wasm-pack pkg/ entry, initialize, call.
import init, { add, greet } from "./pkg/spine_wasm.js";

await init();
const sum = add(19, 23);
if (sum !== 42) throw new Error(`add(19,23) = ${sum}`);
console.log("wasm:", greet("consumer"), "| add(19,23) =", sum);
