// Requires the sibling's product at gen time: the workspace:* edge is
// exercised for real (this file only runs after hello-js's -build ran).
const fs = require("fs");
const path = require("path");
const sib = path.join(__dirname, "..", "..", "hello-js", "dist", "index.js");
if (!fs.existsSync(sib)) {
  console.error("workspace edge broken: hello-js/dist/index.js missing");
  process.exit(1);
}
fs.mkdirSync(path.join(__dirname, "dist"), { recursive: true });
fs.writeFileSync(path.join(__dirname, "dist", "index.js"), "// fixture ui\n");
