import assert from 'node:assert/strict'
import { describe, it } from 'node:test'
import { Reporter } from './reporter.mjs'

/** @import { IReporterLevel } from './reporter.d.ts' */

/** @param {{ date?: boolean, color?: boolean }} [flight] */
const capture = (flight = { date: false, color: false }) => {
  /** @type {{ level: IReporterLevel, parts: string[], args: unknown[] }[]} */
  const logs = []
  /** @type {import('./reporter.d.ts').IReporterOutput} */
  const output = (level, parts, args) => { logs.push({ level, parts, args }) }
  return { logs, output, flight }
}

describe('Reporter', () => {
  // ====================
  // Constructor
  // ====================

  it('creates with defaults', () => {
    const r = new Reporter()
    r.mock().info('test')
    const logs = r.collect()
    assert.equal(logs.length, 1)
    assert.equal(logs[0].level, 'info')
  })

  it('sets initial prefix', () => {
    const r = new Reporter({ prefix: 'app' })
    r.mock().info('test')
    assert.deepEqual(r.collect()[0].prefixes, ['app'])
  })

  it('rejects prefix containing colon', () => {
    assert.throws(() => new Reporter({ prefix: 'a:b' }), /cannot contain ":"/)
  })

  it('falls back invalid level to info', () => {
    const r = new Reporter({ level: /** @type {IReporterLevel} */ (/** @type {unknown} */ ('invalid')) })
    r.mock().debug('no').info('yes')
    assert.equal(r.collect().length, 1)
  })

  // ====================
  // Level Filtering
  // ====================

  it('filters logs by threshold', () => {
    const r = new Reporter({ level: 'warn' })
    r.mock().debug('no').info('no').warn('yes').error('yes')
    const logs = r.collect()
    assert.equal(logs.length, 2)
    assert.equal(logs[0].level, 'warn')
    assert.equal(logs[1].level, 'error')
  })

  it('falls back invalid log() level to default', () => {
    const r = new Reporter({ level: 'warn' })
    r.mock().log(/** @type {IReporterLevel} */ (/** @type {unknown} */ ('invalid')), 'test')
    assert.equal(r.collect()[0].level, 'warn')
  })

  // ====================
  // Prefix Stack
  // ====================

  it('attach returns detach function that restores prefix state', () => {
    const r = new Reporter({ prefix: 'app' })
    r.mock()
    r.info('1')
    const detach1 = r.attach('theme')
    r.info('2')
    const detach2 = r.attach('apply')
    r.info('3')
    detach2()
    r.info('4')
    detach1()
    r.info('5')
    const logs = r.collect()
    assert.deepEqual(logs.map(l => l.prefixes), [
      ['app'],
      ['app', 'theme'],
      ['app', 'theme', 'apply'],
      ['app', 'theme'],
      ['app'],
    ])
  })

  it('detach skips inner prefixes when outer detach is called first', () => {
    const r = new Reporter({ prefix: 'app' })
    r.mock()
    const detach1 = r.attach('a')
    r.attach('b')
    r.attach('c')
    r.info('deep')
    detach1()
    r.info('restored')
    const logs = r.collect()
    assert.deepEqual(logs.map(l => l.prefixes), [
      ['app', 'a', 'b', 'c'],
      ['app'],
    ])
  })

  it('rejects attach prefix containing colon', () => {
    assert.throws(() => new Reporter().attach('a:b'), /cannot contain ":"/)
  })

  it('attach without initial prefix works correctly', () => {
    const r = new Reporter()
    r.mock()
    const detach = r.attach('sub')
    r.info('1')
    detach()
    r.info('2')
    const logs = r.collect()
    assert.deepEqual(logs.map(l => l.prefixes), [['sub'], []])
  })

  // ====================
  // Lazy Evaluation
  // ====================

  it('evaluates function args only when level passes', () => {
    const r = new Reporter({ level: 'info' })
    r.mock()
    let called = false
    r.debug(() => { called = true; return 'x' })
    assert.equal(called, false)
    r.info(() => { called = true; return 'y' })
    assert.equal(called, true)
    assert.deepEqual(r.collect()[0].args, ['y'])
  })

  // ====================
  // Mock & Collect
  // ====================

  it('captures logs in mock mode', () => {
    const r = new Reporter({ level: 'debug' })
    r.mock().debug('d').info('i').warn('w').error('e')
    const logs = r.collect()
    assert.deepEqual(logs.map(l => l.level), ['debug', 'info', 'warn', 'error'])
  })

  it('includes date in captured entries', () => {
    const r = new Reporter()
    r.mock().info('test')
    assert.ok(r.collect()[0].date instanceof Date)
  })

  it('returns empty array when collect without mock', () => {
    assert.deepEqual(new Reporter().collect(), [])
  })

  // ====================
  // Output Formatting
  // ====================

  it('uses custom output function', () => {
    const { logs, output, flight } = capture()
    new Reporter({ prefix: 'app', output, flight }).info('hello', 'world')
    assert.equal(logs[0].level, 'info')
    assert.deepEqual(logs[0].parts, ['[app]'])
    assert.deepEqual(logs[0].args, ['hello', 'world'])
  })

  it('uses level name as tag when no prefix', () => {
    const { logs, output, flight } = capture()
    const r = new Reporter({ output, flight, level: 'debug' })
    r.debug('d').info('i').warn('w').error('e')
    assert.deepEqual(logs.map(l => l.parts[0]), ['[debug]', '[info]', '[warn]', '[error]'])
  })

  it('includes timestamp by default', () => {
    const { logs, output, flight } = capture({ color: false })
    new Reporter({ output, flight }).info('test')
    assert.equal(logs[0].parts.length, 2)
    assert.match(logs[0].parts[0], /^\d{4}-\d{2}-\d{2}T/)
  })

  it('excludes timestamp when date is false', () => {
    const { logs, output, flight } = capture({ date: false, color: false })
    new Reporter({ output, flight }).info('test')
    assert.equal(logs[0].parts.length, 1)
  })

  it('formats tag with ANSI colors', () => {
    const { logs, output, flight } = capture({ date: false, color: true })
    new Reporter({ prefix: 'app', output, flight }).info('test')
    assert.ok(logs[0].parts[0].includes('\x1b['))
  })

  it('formats timestamp with ANSI dim', () => {
    const { logs, output, flight } = capture({ date: true, color: true })
    new Reporter({ prefix: 'app', output, flight }).info('test')
    assert.ok(logs[0].parts[0].includes('\x1b[90m'))
  })

  it('uses console methods by default', () => {
    const r = new Reporter({ prefix: 'test', level: 'debug' })
    r.debug('d').info('i').warn('w').error('e')
  })
})
