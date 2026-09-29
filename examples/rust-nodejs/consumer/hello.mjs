// The node consumer: loads the .node addon (CommonJS entry; mjs uses
// createRequire) and asserts the API.
import { createRequire } from "module";
const require = createRequire(import.meta.url);
const spine = require("./spine-node.node");

const sum = spine.add(19, 23);
if (sum !== 42) throw new Error(`add(19,23) = ${sum}`);
console.log("node:", spine.greet("consumer"), "| add(19,23) =", sum);
