// The vendored "third-party" JS library (file: dependency -- npm links it
// into node_modules as a symlink, NO network). No source maps: js-debug
// binds breakpoints in this file directly at its realpath under vendor/.
function banner(where) {
  return where + "/vendorlib: OK";
}

module.exports = { banner };
