// The source-level debug carrier: this file IS the launch `program` of the
// js-debug row PolyOrch generates (package main -> src/index.js). Plain JS,
// so breakpoints set here bind directly -- no build step, no source maps.
function collatz(n) {
  let steps = 0;
  while (n !== 1) {
    n = n % 2 === 0 ? n / 2 : 3 * n + 1;
    steps += 1;
  }
  return steps;
}

function total(limit) {
  let sum = 0;
  for (let i = 1; i <= limit; i++) {
    sum += collatz(i);
  }
  return sum;
}

console.log(`node-basic total=${total(5)}`);
