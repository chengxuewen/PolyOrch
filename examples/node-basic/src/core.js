"use strict";
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

module.exports = { collatz, total };
