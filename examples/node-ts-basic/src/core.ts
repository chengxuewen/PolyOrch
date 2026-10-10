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
