import assert from 'node:assert/strict'
import { test } from 'node:test'
import { getVirtualListRange } from './range.ts'

const viewport = {
  scrollTop: 0,
  height: 330,
  paddingTop: 0,
  paddingBottom: 0,
}

test('empty and short lists keep their ranges inside the data', () => {
  assert.deepEqual(getVirtualListRange(0, 33, 5, viewport), { startIndex: 0, endIndex: 0 })
  assert.deepEqual(getVirtualListRange(3, 33, 5, viewport), { startIndex: 0, endIndex: 3 })
})

test('partial rows remain rendered at both viewport edges', () => {
  assert.deepEqual(getVirtualListRange(100, 33, 0, { ...viewport, scrollTop: 16.5 }), {
    startIndex: 0,
    endIndex: 11,
  })
  assert.deepEqual(getVirtualListRange(100, 33, 0, { ...viewport, scrollTop: 33 }), {
    startIndex: 1,
    endIndex: 11,
  })
})

test('overscan surrounds visible rows without exceeding the final item', () => {
  assert.deepEqual(getVirtualListRange(100, 33, 5, { ...viewport, scrollTop: 330 }), {
    startIndex: 5,
    endIndex: 25,
  })
  assert.deepEqual(getVirtualListRange(100, 33, 5, { ...viewport, scrollTop: 2970 }), {
    startIndex: 85,
    endIndex: 100,
  })
})

test('filtering or collapsing at the bottom clamps a stale scroll position', () => {
  const previousViewport = { ...viewport, scrollTop: 30_000 }
  assert.deepEqual(getVirtualListRange(20, 33, 0, previousViewport), {
    startIndex: 10,
    endIndex: 20,
  })
  assert.deepEqual(getVirtualListRange(2, 33, 0, previousViewport), {
    startIndex: 0,
    endIndex: 2,
  })
  assert.deepEqual(getVirtualListRange(0, 33, 0, previousViewport), {
    startIndex: 0,
    endIndex: 0,
  })
})

test('padding offsets visible rows and contributes to the maximum scroll position', () => {
  const paddedViewport = { ...viewport, paddingTop: 8, paddingBottom: 8, scrollTop: 33 }
  assert.deepEqual(getVirtualListRange(100, 33, 0, paddedViewport), {
    startIndex: 0,
    endIndex: 11,
  })
  assert.deepEqual(getVirtualListRange(20, 33, 0, { ...paddedViewport, scrollTop: 30_000 }), {
    startIndex: 10,
    endIndex: 20,
  })
})

test('viewport growth and negative elastic scrolling keep visible rows covered', () => {
  assert.deepEqual(getVirtualListRange(20, 33, 0, { ...viewport, height: 660, scrollTop: 330 }), {
    startIndex: 0,
    endIndex: 20,
  })
  assert.deepEqual(getVirtualListRange(100, 33, 0, { ...viewport, scrollTop: -100 }), {
    startIndex: 0,
    endIndex: 10,
  })
})

test('large data sets only render the viewport and overscan', () => {
  assert.deepEqual(getVirtualListRange(1_000_000, 33, 5, { ...viewport, scrollTop: 16_500_000 }), {
    startIndex: 499_995,
    endIndex: 500_015,
  })
})

test('the range covers exactly the intersecting row rectangles with zero overscan', () => {
  for (const itemHeight of [0.5, 17, 33]) {
    for (const height of [1, 40, 200]) {
      for (const paddingTop of [0, 8, 100]) {
        const itemCount = 30
        const paddingBottom = 8
        const scrollHeight = itemCount * itemHeight + paddingTop + paddingBottom
        for (let scrollTop = 0; scrollTop <= Math.max(0, scrollHeight - height); scrollTop += 7.5) {
          const { startIndex, endIndex } = getVirtualListRange(itemCount, itemHeight, 0, {
            scrollTop,
            height,
            paddingTop,
            paddingBottom,
          })
          const expected = []
          for (let index = 0; index < itemCount; index++) {
            const top = paddingTop + index * itemHeight - scrollTop
            const bottom = top + itemHeight
            if (top < height && bottom > 0) expected.push(index)
          }
          const actual = Array.from(
            { length: endIndex - startIndex },
            (_, index) => startIndex + index,
          )
          assert.deepEqual(actual, expected)
        }
      }
    }
  }
})

test('invalid sizing options fail explicitly', () => {
  for (const itemHeight of [0, -1, NaN, Infinity]) {
    assert.throws(() => getVirtualListRange(10, itemHeight, 5, viewport), RangeError)
  }
  for (const overscan of [-1, 0.5, NaN, Infinity]) {
    assert.throws(() => getVirtualListRange(10, 33, overscan, viewport), RangeError)
  }
})
