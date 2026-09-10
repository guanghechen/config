import assert from 'node:assert/strict'
import { test } from 'node:test'
import clsx from '../src/common/util/clsx.ts'

test('joins class strings without trimming, deduplicating or merging Tailwind utilities', () => {
  assert.equal(clsx(), '')
  assert.equal(clsx('p-2', 'p-4', 'p-2'), 'p-2 p-4 p-2')
  assert.equal(clsx(' left ', 'right'), ' left  right')
})

test('ignores falsy inputs and boolean flags but preserves nonzero numbers', () => {
  assert.equal(clsx(null, undefined, false, true, '', 0, -0, NaN), '')
  assert.equal(clsx('row', 1, -2, Infinity), 'row 1 -2 Infinity')
  assert.equal(clsx(1n, 0n), '')
})

test('flattens nested and readonly arrays with no extra separators', () => {
  const values = Object.freeze(['a', Object.freeze([null, 'b', ['', false, 'c']])])
  assert.equal(clsx(values, [], [['']], 'd'), 'a b c d')
})

test('includes object keys based on value truthiness, not stringified values', () => {
  assert.equal(
    clsx({ active: true, disabled: false, count: 1, zero: 0, nil: null }),
    'active count',
  )
  assert.equal(clsx({ array: [], object: {}, text: 'no', bigint: 1n }), 'array object text bigint')
  assert.equal(
    clsx(['base', { 'hover:bg-gray-200 dark:hover:bg-gray-600': true }]),
    'base hover:bg-gray-200 dark:hover:bg-gray-600',
  )
})

test('retains clsx enumerable inherited-key behavior and ignores symbol keys', () => {
  const value = Object.assign(Object.create({ inherited: true }), { own: true })
  value[Symbol('ignored')] = true
  assert.equal(clsx(value), 'own inherited')
  assert.equal(clsx(Object.assign(Object.create(null), { active: true })), 'active')
})

test('preserves empty object key and numeric key behavior', () => {
  assert.equal(clsx({ '': true, a: true }), 'a')
  assert.equal(clsx({ a: true, '': true }), 'a ')
  assert.equal(clsx({ 0: true, 2: true, 1: false }), '0 2')
})

test('does not mutate inputs or invoke callbacks/toString', () => {
  const args = Object.freeze(['a', Object.freeze({ b: true })])
  assert.equal(clsx(args), 'a b')
  assert.equal(
    clsx(() => {
      throw new Error('must not invoke')
    }, Symbol('ignored')),
    '',
  )
  assert.equal(
    clsx({
      toString() {
        throw new Error('must not coerce')
      },
    }),
    'toString',
  )
})
