const MOD = 10000000000000000;
const DUCKS = 11;

const calculate = (array, index) => {
  let firstItem = array[index];
  let firstItemEdge = (firstItem + MOD / 2) % MOD;
  if (firstItem > firstItemEdge) {
    const temp = firstItem;
    firstItem = firstItemEdge;
    firstItemEdge = temp;
  }
  let size = array.filter(
    (item) => item >= firstItem && item <= firstItemEdge
  ).length;
  if (size < array.length / 2) {
    size = array.length - size;
  }
  return size;
};

const getMaxGroupSize = (array) => {
  let max = 0;
  for (let i = 0; i < array.length; i++) {
    const size1 = calculate(array, i);
    if (size1 > max) {
      max = size1;
    }
    if (size1 < DUCKS) {
      const size2 = calculate(
        array.map((item) => (item + MOD / 2) % MOD),
        i
      );
      if (size2 > max) {
        max = size2;
      }
    }
  }
  return max;
};

const result = {};
for (let i = 0; i < 1000000; i++) {
  const array = new Array(DUCKS)
    .fill(0)
    .map(() => Math.floor(Math.random() * MOD));
  const size = getMaxGroupSize(array);
  if (size === 2) {
    console.log(array);
  }
  result[size] = result[size] ? result[size] + 1 : 1;
}
console.log(result);
