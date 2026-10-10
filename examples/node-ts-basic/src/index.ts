// The TS carrier (D37): source-level debugging via built entry + source maps.
// This file compiles to dist/index.js with dist/index.js.map; the generated
// launch row's `program` is that built entry and js-debug maps breakpoints
// back into THIS file through the row's outFiles glob.
export function collatz(n: number): number {
  let steps = 0;
  while (n !== 1) {
    n = n % 2 === 0 ? n / 2 : 3 * n + 1;
    steps += 1;
  }
  return steps;
}

export function total(limit: number): number {
  let sum = 0;
  for (let i = 1; i <= limit; i++) {
    sum += collatz(i);
  }
  return sum;
}

console.log(`node-ts-basic total=${total(5)}`);
