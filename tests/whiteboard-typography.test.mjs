import assert from 'node:assert/strict'
import { test } from 'node:test'
import { DEFAULT_STYLE, createDocument } from '../shared/whiteboard/model.ts'
import { fitTextNode, textFont, textLineHeight, wrapText } from '../shared/whiteboard/text.ts'
import { parseDocument } from '../shared/whiteboard/document.ts'
import {
  labelArea,
  labelLayout,
  moveElements,
  resolveEndpoint,
} from '../shared/whiteboard/geometry.ts'
import { resizeBounds, resizeElements } from '../shared/whiteboard/transforms.ts'
import { applyCommands } from '../shared/whiteboard/commands.ts'
import { BoardStore } from '../src/view/whiteboard/store.ts'

const text = (patch = {}) => ({
  id: 'text',
  type: 'text',
  text: 'Hello',
  x: 40,
  y: 50,
  width: 260,
  height: 100,
  style: DEFAULT_STYLE,
  ...patch,
})
const document = elements => ({ ...createDocument(), elements })
const segments = new Intl.Segmenter(undefined, { granularity: 'grapheme' })
const measure = value =>
  Array.from(segments.segment(value)).reduce(
    (total, { segment }) => total + (segment.codePointAt(0) > 255 ? 20 : 10),
    0,
  )

test('typography and auto-size round trip; invalid values never replace the current scene', () => {
  const original = document([text()]),
    store = new BoardStore(original)
  for (const fontFamily of ['hand', 'sans', 'mono']) {
    const styled = document([
      text({
        autoSize: true,
        style: {
          ...DEFAULT_STYLE,
          fontSize: 48,
          fontFamily,
          fontWeight: 'bold',
          textAlign: 'right',
        },
      }),
    ])
    assert.deepEqual(parseDocument(JSON.stringify(styled)), styled)
  }
  for (const patch of [
    { fontSize: 7 },
    { fontSize: 201 },
    { fontSize: null },
    { fontFamily: ['mono'] },
    { fontWeight: 'heavy' },
    { textAlign: 'justify' },
  ]) {
    assert.throws(() =>
      store.replace(
        parseDocument(JSON.stringify(document([text({ style: { ...DEFAULT_STYLE, ...patch } })]))),
      ),
    )
    assert.equal(store.getDocument(), original)
  }
  assert.throws(() => parseDocument(JSON.stringify(document([text({ autoSize: 'yes' })]))))
  assert.throws(() =>
    parseDocument(
      JSON.stringify(document([{ ...text(), type: 'image', url: '/picture.png', autoSize: true }])),
    ),
  )
  assert.match(textFont(DEFAULT_STYLE, 'text'), /^24px/)
  assert.match(textFont(DEFAULT_STYLE, 'label'), /^20px/)
})

test('wrapping preserves words, grapheme clusters and explicit newlines; clipped content uses an ellipsis', () => {
  assert.deepEqual(wrapText('hello world', 60, 100, 20, measure).lines, ['hello', 'world'])
  assert.deepEqual(wrapText('hello  ', 50, 20, 20, measure).lines, ['hello'])
  assert.deepEqual(wrapText('hello\n   ', 50, 100, 20, measure).lines, ['hello', ''])
  assert.deepEqual(wrapText('中文测试', 40, 100, 20, measure).lines, ['中文', '测试'])
  assert.deepEqual(wrapText('👩‍💻👩‍💻👩‍💻', 40, 100, 20, measure).lines, ['👩‍💻👩‍💻', '👩‍💻'])
  assert.deepEqual(wrapText('a\r\nb\n', 40, 100, 20, measure).lines, ['a', 'b', ''])
  assert.deepEqual(wrapText('hello world again', 60, 20, 20, measure).lines, ['hell…'])
  assert.deepEqual(wrapText('中文', 1, 100, 20, measure).lines, [])
  let calls = 0
  const clipped = wrapText('a'.repeat(100000), 240, 300, 20, value => {
    calls += 1
    return value.length * 8
  })
  assert.equal(clipped.lines.length, 15)
  assert.ok(clipped.lines.at(-1).endsWith('…'))
  assert.ok(calls < 200, `Unbounded measurement work: ${calls}`)
})

test('automatic text and shape dimensions fit content while preserving origin and connection anchors', () => {
  const original = text({ autoSize: true })
  const fitted = fitTextNode(original, measure)
  assert.deepEqual(
    { x: fitted.x, y: fitted.y, width: fitted.width, height: fitted.height },
    { x: 40, y: 50, width: 58, height: 40 },
  )
  assert.equal(fitTextNode(fitted, measure), fitted)
  assert.equal(fitTextNode(text(), measure).width, 260)
  const multiline = fitTextNode({ ...fitted, text: 'Hello\nWorld' }, measure)
  assert.equal(multiline.height, 72)
  const kerned = value => value.length * 10 - (value.match(/AV/g)?.length ?? 0) * 4
  const long = fitTextNode(text({ autoSize: true, text: 'AV'.repeat(120) }), kerned)
  const wrapped = wrapText(long.text, long.width - 8, long.height, 32, kerned)
  assert.equal(wrapped.lines.join(''), long.text)
  assert.ok(long.height >= wrapped.height + 8)
  for (const shape of ['rectangle', 'ellipse', 'diamond']) {
    const element = { ...original, type: 'shape', shape, label: '中文', autoSize: true }
    const sized = fitTextNode(element, measure)
    const area = labelArea(sized, new Map())
    assert.ok(area.width >= 40 && area.height >= 26)
    assert.deepEqual(
      resolveEndpoint({ nodeId: 'text', x: 1, y: 0.5 }, new Map([['text', sized]])),
      { x: 40 + sized.width, y: 50 + sized.height / 2 },
    )
    const blank = { ...element, label: '' }
    assert.equal(fitTextNode(blank, measure), blank)
  }
})

test('text alignment positions labels within their geometry and fontsize scales the label envelope', () => {
  const base = {
    id: 'edge',
    type: 'edge',
    from: { x: 0, y: 0 },
    to: { x: 500, y: 0 },
    label: 'A',
    style: DEFAULT_STYLE,
  }
  const small = labelArea(base, new Map())
  const large = labelArea({ ...base, style: { ...DEFAULT_STYLE, fontSize: 40 } }, new Map())
  assert.equal(large.width, small.width * 2)
  const bounds = ['left', 'center', 'right'].map(
    textAlign => labelLayout({ ...base, style: { ...DEFAULT_STYLE, textAlign } }, new Map()).bounds,
  )
  assert.ok(bounds[0].x < bounds[1].x && bounds[1].x < bounds[2].x)
  assert.equal(textLineHeight({ ...DEFAULT_STYLE, fontSize: 40 }, 'label'), 52)
})

test('a normalized content edit is one undo action and manual resizing exits auto-size', () => {
  const normalize = doc => {
    const elements = doc.elements.map(element =>
      element.type === 'edge' ? element : fitTextNode(element, measure),
    )
    return elements.every((element, index) => element === doc.elements[index])
      ? doc
      : { ...doc, elements }
  }
  const store = new BoardStore(document([text({ autoSize: true })]), normalize)
  const initial = store.getDocument(),
    node = initial.elements[0]
  store.commit({ ...initial, elements: [{ ...node, text: 'Longer new content' }] })
  const changed = store.getDocument()
  assert.ok(changed.elements[0].width > node.width)
  store.undo()
  assert.equal(store.getDocument(), initial)
  store.redo()
  assert.equal(store.getDocument(), changed)
  const selected = new Set(['text'])
  const moved = moveElements(changed.elements, selected, { x: 10, y: 20 })
  assert.equal(moved[0].autoSize, true)
  const bounds = resizeBounds(changed.elements, selected)
  const resized = resizeElements(
    changed.elements,
    selected,
    bounds,
    { x: 1, y: 1 },
    { x: bounds.x + 400, y: bounds.y + 200 },
    false,
  )
  assert.equal(resized[0].autoSize, false)
  store.preview(resized)
  store.commit()
  assert.equal(store.getDocument().elements[0].width, 400)
  store.undo()
  assert.equal(store.getDocument(), changed)
})

test('agent geometry overrides disable automatic size unless explicitly retained', () => {
  const original = document([text({ autoSize: true })])
  const batch = patch => ({
    kind: 'yoz.whiteboard.commands',
    schemaVersion: 1,
    documentId: original.id,
    commands: [{ op: 'update', id: 'text', patch }],
  })
  assert.equal(applyCommands(original, batch({ width: 400 })).elements[0].autoSize, false)
  assert.equal(
    applyCommands(original, batch({ width: 400, autoSize: true })).elements[0].autoSize,
    true,
  )
  assert.equal(
    applyCommands(original, batch({ text: 'Updated externally' })).elements[0].autoSize,
    true,
  )
})
