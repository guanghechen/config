import assert from 'node:assert/strict'
import { test } from 'node:test'
import { fileURLToPath } from 'node:url'
import ts from 'typescript'
import debounce from '../src/common/util/debounce.ts'
import throttle from '../src/common/util/throttle.ts'

// Run with Node 24+: node --test tests/timing.test.mjs
// Every expected trace describes our contract; no third-party implementation is the oracle.
const utilities = { debounce, throttle }

function clock(t) {
  t.mock.timers.enable({ apis: ['Date', 'setTimeout'], now: 0 })
  return t.mock.timers
}

for (const [name, create] of Object.entries(utilities)) {
  for (const leading of [false, true]) {
    for (const trailing of [false, true]) {
      test(`${name}: leading=${leading}, trailing=${trailing}`, t => {
        const timer = clock(t)
        const calls = []
        const fn = create(value => calls.push([Date.now(), value]), 100, { leading, trailing })
        fn('first')
        assert.deepEqual(calls, leading ? [[0, 'first']] : [])
        timer.tick(40)
        fn('last')
        timer.tick(60)
        if (name === 'debounce') timer.tick(40)
        const expected = leading ? [[0, 'first']] : []
        if (trailing) expected.push([name === 'debounce' ? 140 : 100, 'last'])
        assert.deepEqual(calls, expected)
        timer.tick(1000)
        assert.deepEqual(calls, expected)
      })
    }
  }

  test(`${name}: a single leading call never duplicates on the trailing edge`, t => {
    const timer = clock(t)
    const calls = []
    const fn = create(value => calls.push(value), 100, { leading: true, trailing: true })
    fn('once')
    timer.tick(1000)
    assert.deepEqual(calls, ['once'])
  })

  test(`${name}: both disabled remain disabled when a timer is overdue`, t => {
    const timer = clock(t)
    const calls = []
    const fn = create(value => calls.push(value), 100, { leading: false, trailing: false })
    fn('first')
    // Advance wall time without running callbacks, as during a blocked event loop.
    timer.setTime(150)
    fn('overdue')
    fn.flush()
    timer.tick(1000)
    assert.deepEqual(calls, [])
  })

  test(`${name}: zero wait with leading disabled defers and keeps the last call`, t => {
    const timer = clock(t)
    const calls = []
    const fn = create(value => calls.push(value), 0, { leading: false, trailing: true })
    fn('first')
    fn('last')
    assert.deepEqual(calls, [])
    timer.tick(0)
    assert.deepEqual(calls, ['last'])
  })

  test(`${name}: zero wait with both edges disabled never invokes`, t => {
    const timer = clock(t)
    const calls = []
    const fn = create(value => calls.push(value), 0, { leading: false, trailing: false })
    fn('first')
    fn('last')
    timer.tick(0)
    assert.deepEqual(calls, [])
  })

  test(`${name}: cancel drops pending arguments and resets the next burst`, t => {
    const timer = clock(t)
    const calls = []
    const fn = create(value => calls.push(value), 100, { leading: true, trailing: true })
    fn('first')
    timer.tick(20)
    fn('discard')
    fn.cancel()
    fn.cancel()
    assert.equal(fn.flush(), 1)
    timer.tick(200)
    assert.deepEqual(calls, ['first'])
    fn('restart')
    assert.deepEqual(calls, ['first', 'restart'])
    timer.tick(100)
    assert.deepEqual(calls, ['first', 'restart'])
  })

  test(`${name}: flush uses the latest receiver, args and return value exactly once`, t => {
    const timer = clock(t)
    const calls = []
    const fn = create(
      function (value) {
        calls.push([this.label, value])
        return `${this.label}:${value}`
      },
      100,
      { leading: false },
    )
    assert.equal(fn.call({ label: 'old' }, 1), undefined)
    timer.tick(20)
    fn.call({ label: 'new' }, 2)
    assert.equal(fn.flush(), 'new:2')
    assert.equal(fn.flush(), 'new:2')
    timer.tick(1000)
    assert.deepEqual(calls, [['new', 2]])
  })

  test(`${name}: cancel after flush leaves no callback that can revive old work`, t => {
    const timer = clock(t)
    const calls = []
    const fn = create(value => calls.push(value), 100, { leading: false })
    fn('flushed')
    fn.flush()
    timer.tick(20)
    fn('discard')
    fn.cancel()
    timer.tick(1000)
    assert.deepEqual(calls, ['flushed'])
  })

  test(`${name}: reentrant calls preserve their pending arguments`, t => {
    const timer = clock(t)
    const calls = []
    const fn = create(
      value => {
        calls.push(value)
        if (value === 'outer') fn('inner')
      },
      100,
      { leading: true },
    )
    fn('outer')
    timer.tick(100)
    assert.deepEqual(calls, ['outer', 'inner'])
    timer.tick(1000)
    assert.deepEqual(calls, ['outer', 'inner'])
  })

  test(`${name}: cancellation inside a callback is final`, t => {
    const timer = clock(t)
    const calls = []
    const fn = create(
      value => {
        calls.push(value)
        fn('discard')
        fn.cancel()
      },
      100,
      { leading: true },
    )
    fn('first')
    timer.tick(1000)
    assert.deepEqual(calls, ['first'])
  })

  test(`${name}: callback exceptions propagate and do not poison later calls`, t => {
    const timer = clock(t)
    const failure = new Error('callback failure')
    let count = 0
    const fn = create(
      () => {
        count += 1
        if (count === 1) throw failure
        return count
      },
      100,
      { leading: true },
    )
    assert.throws(
      () => fn(),
      error => error === failure,
    )
    timer.tick(100)
    assert.equal(fn(), 2)
  })

  test(`${name}: async callbacks preserve promise identity`, t => {
    const timer = clock(t)
    const promise = Promise.resolve(42)
    const fn = create(() => promise, 100, { leading: true })
    assert.equal(fn(), promise)
    assert.equal(fn(), promise)
    assert.equal(fn.flush(), promise)
    fn.cancel()
    timer.tick(1000)
  })
}

test('debounce: a continuous burst waits for a full quiet interval', t => {
  const timer = clock(t)
  const calls = []
  const fn = debounce(value => calls.push([Date.now(), value]), 100)
  fn(0)
  for (let i = 1; i <= 5; i++) {
    timer.tick(60)
    fn(i)
    assert.deepEqual(calls, [])
  }
  timer.tick(99)
  assert.deepEqual(calls, [])
  timer.tick(1)
  assert.deepEqual(calls, [[400, 5]])
})

test('throttle: continuous calls produce periodic trailing updates without starvation', t => {
  const timer = clock(t)
  const calls = []
  const fn = throttle(value => calls.push([Date.now(), value]), 100)
  for (let time = 0; time <= 300; time += 10) {
    if (time > 0) timer.tick(10)
    if (time % 30 === 0) fn(time)
  }
  assert.deepEqual(calls, [
    [0, 0],
    [100, 90],
    [200, 180],
    [300, 270],
  ])
  timer.tick(100)
  assert.deepEqual(calls.at(-1), [400, 300])
})

test('throttle: flush retains a cooldown for a subsequent call', t => {
  const timer = clock(t)
  const calls = []
  const fn = throttle(value => calls.push([Date.now(), value]), 100)
  fn(1)
  timer.tick(20)
  fn(2)
  fn.flush()
  fn.flush()
  timer.tick(20)
  fn(3)
  timer.tick(79)
  assert.deepEqual(calls, [
    [0, 1],
    [20, 2],
  ])
  timer.tick(1)
  assert.deepEqual(calls, [
    [0, 1],
    [20, 2],
    [120, 3],
  ])
})

test('throttle: a new call cannot run too soon after a trailing invocation', t => {
  const timer = clock(t)
  const calls = []
  const fn = throttle(value => calls.push([Date.now(), value]), 100)
  fn(1)
  timer.tick(90)
  fn(2)
  timer.tick(10)
  timer.tick(90)
  fn(3)
  assert.deepEqual(calls, [
    [0, 1],
    [100, 2],
  ])
  timer.tick(10)
  assert.deepEqual(calls, [
    [0, 1],
    [100, 2],
    [200, 3],
  ])
})

test('throttle: an overdue timer uses the latest call without duplicate execution', t => {
  const timer = clock(t)
  const calls = []
  const fn = throttle(value => calls.push([Date.now(), value]), 100)
  fn(1)
  timer.setTime(150)
  fn(2)
  timer.tick(0)
  assert.deepEqual(calls, [
    [0, 1],
    [150, 2],
  ])
  timer.tick(100)
  assert.deepEqual(calls, [
    [0, 1],
    [150, 2],
  ])
})

test('timing utilities preserve argument, receiver and async return types', () => {
  const file = fileURLToPath(new URL('../__timing_type_check__.ts', import.meta.url))
  const source = `
    import debounce from './src/common/util/debounce'
    import throttle from './src/common/util/throttle'
    const d = debounce((n: number, label: string) => label + n, 100)
    const value: string | undefined = d(1, 'x')
    const flushed: string | undefined = d.flush()
    d.cancel()
    // @ts-expect-error invalid argument type
    d('bad', 'x')
    // @ts-expect-error missing argument
    d(1)
    const t = throttle(async (n: number) => n + 1, 100)
    const promise: Promise<number> | undefined = t(1)
    // @ts-expect-error invalid async callback argument
    t('bad')
    const method = debounce(function (this: { value: number }, n: number) {
      return this.value + n
    }, 100)
    const result: number | undefined = method.call({ value: 2 }, 3)
    // @ts-expect-error invalid receiver
    method.call({ value: 'bad' }, 3)
  `
  const options = {
    strict: true,
    noEmit: true,
    target: ts.ScriptTarget.ES2022,
    module: ts.ModuleKind.ESNext,
    moduleResolution: ts.ModuleResolutionKind.Bundler,
    types: [],
    skipLibCheck: true,
  }
  const host = ts.createCompilerHost(options)
  const readFile = host.readFile.bind(host)
  const fileExists = host.fileExists.bind(host)
  host.readFile = path => (path === file ? source : readFile(path))
  host.fileExists = path => path === file || fileExists(path)
  const program = ts.createProgram([file], options, host)
  const diagnostics = ts.getPreEmitDiagnostics(program)
  assert.deepEqual(
    diagnostics.map(diagnostic => ts.flattenDiagnosticMessageText(diagnostic.messageText, '\n')),
    [],
  )
})
