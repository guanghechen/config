export const DEFAULT_JSON = {
  empty: {
    a: {},
    b: [],
    story:
      "Once upon a time in a small coastal village, a young fisher named Maya discovered an unusual bottle washed ashore. Inside was a map leading to a hidden cove. Curiosity sparked, she sailed at dawn, navigating treacherous waters until reaching the secluded bay. There stood an ancient lighthouse, abandoned for decades. Inside, she found journals detailing the life of a lonely keeper who had discovered how to communicate with whales through music. Maya restored the lighthouse and learned his methods. Soon, whales returned to the waters, bringing prosperity to her village. Years later, tourists would visit to hear Maya's enchanting melodies and watch as massive creatures danced in the waves, a testament to how one unexpected discovery can transform a life and community forever.",
  },
  numbers: Array.from(new Array(300))
    .map((_, i): unknown => i)
    .concat({ a: 1, b: 2, c: 3, d: { e: 5, f: 7 }, g: [10, 11, '23'] }),
  name: 'lemon',
  age: 10,
  address: ['a', 'bc', 'def'],
  others: {
    favorite: [
      'apple',
      'banana',
      {
        name: 'orange',
        variants: ['italic', 'bold'],
      },
    ],
    subjects: {
      science: 'A',
    },
  },
  values: {
    undefined: undefined,
    null: null,
    integer: 1,
    number: 0.2,
    string: 'hello, world!',
    symbol: Symbol.for('lemon_cat'),
    bigint: 20n,
  },
  methods: {
    GET: function (a: string, b: number, c: bigint, d: symbol, e: null, f: undefined): string {
      return [a, b, c, d, e, f].join(',')
    },
    POST: (a: string, b: number, c: bigint, d: symbol, e: null, f: undefined): string =>
      [a, b, c, d, e, f].join(','),
    PUT: () => {},
  },
}
