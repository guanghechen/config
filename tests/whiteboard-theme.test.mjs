import assert from 'node:assert/strict'
import { test } from 'node:test'
import { DARK_PALETTES, LIGHT_PALETTES } from '../src/common/style/palette.ts'
import { DEFAULT_STYLE, createDocument } from '../shared/whiteboard/model.ts'
import { parseDocument } from '../shared/whiteboard/document.ts'
import {
  THEME_COLORS,
  contrastRatio,
  isThemeColor,
  mixColor,
  readableColor,
  resolveStyle,
} from '../shared/whiteboard/colors.ts'

const paletteColors = colors => ({
  'theme:ink': colors.text,
  'theme:paper': colors.base,
  'theme:accent': colors.foam,
  'theme:red': colors.love,
  'theme:amber': colors.gold,
  'theme:green': colors.pine,
  'theme:blue': colors.foam,
  'theme:purple': colors.iris,
})
const node = style => ({
  id: 'node',
  type: 'shape',
  shape: 'rectangle',
  x: 0,
  y: 0,
  width: 200,
  height: 120,
  style,
})

test('theme colors round trip and unknown tokens are rejected without changing legacy colors', () => {
  for (const token of THEME_COLORS) {
    assert.equal(isThemeColor(token), true)
    const document = {
      ...createDocument(),
      elements: [node({ ...DEFAULT_STYLE, stroke: token, fill: token })],
    }
    assert.deepEqual(parseDocument(JSON.stringify(document)), document)
  }
  for (const color of ['theme:missing', 'theme:Ink', 'var(--ink)', 'auto']) {
    assert.throws(
      () =>
        parseDocument(
          JSON.stringify({
            ...createDocument(),
            elements: [node({ ...DEFAULT_STYLE, stroke: color })],
          }),
        ),
      /Invalid style/,
    )
  }
  const legacy = {
    ...createDocument(),
    elements: [node({ stroke: '#293241', fill: '#ffffff', strokeWidth: 2, roughness: 1 })],
  }
  assert.deepEqual(parseDocument(JSON.stringify(legacy)), legacy)
})

test('all site palettes provide readable semantic ink on paper, solid fills and hachure', () => {
  for (const palette of [...LIGHT_PALETTES, ...DARK_PALETTES]) {
    const colors = paletteColors(palette.colors)
    for (const stroke of THEME_COLORS) {
      for (const fill of THEME_COLORS) {
        for (const fillPattern of ['solid', 'hachure', 'cross-hatch']) {
          const resolved = resolveStyle(
            { ...DEFAULT_STYLE, stroke, fill, fillPattern },
            colors,
            true,
          )
          const background = fillPattern === 'solid' ? resolved.fill : colors['theme:paper']
          assert.ok(
            contrastRatio(resolved.stroke, background) >= 4.5,
            `${palette.id} ${stroke}/${fill} ${fillPattern}`,
          )
        }
      }
    }
  }
})

test('custom colors remain fixed and resolving a theme does not mutate the document', () => {
  const style = Object.freeze({ ...DEFAULT_STYLE, stroke: '#123456', fill: '#fedcba' })
  for (const palette of [...LIGHT_PALETTES, ...DARK_PALETTES])
    assert.equal(resolveStyle(style, paletteColors(palette.colors), true), style)
  const themed = Object.freeze({ ...DEFAULT_STYLE, stroke: 'theme:blue', fill: 'theme:amber' })
  const document = { ...createDocument(), elements: [node(themed)] },
    before = JSON.stringify(document)
  const light = resolveStyle(themed, paletteColors(LIGHT_PALETTES[0].colors), true)
  const dark = resolveStyle(themed, paletteColors(DARK_PALETTES[0].colors), true)
  assert.notEqual(light.stroke, dark.stroke)
  assert.notEqual(light.fill, dark.fill)
  assert.equal(JSON.stringify(document), before)
})

test('automatic ink adapts to explicit light fills without darkening text on the dark canvas', () => {
  const colors = paletteColors(DARK_PALETTES[0].colors)
  const style = { ...DEFAULT_STYLE, fill: '#ffffff' }
  const shape = resolveStyle(style, colors, true),
    text = resolveStyle(style, colors)
  assert.ok(contrastRatio(shape.stroke, '#ffffff') >= 4.5)
  assert.equal(text.stroke, colors['theme:ink'])
  assert.ok(contrastRatio(text.stroke, colors['theme:paper']) >= 4.5)
  assert.equal(resolveStyle({ ...style, fill: 'transparent' }, colors, true).fill, 'transparent')
})

test('solid theme fills are tinted while hachure retains a clear pigment', () => {
  const colors = paletteColors(LIGHT_PALETTES[1].colors)
  const style = { ...DEFAULT_STYLE, fill: 'theme:blue' }
  const solid = resolveStyle(style, colors, true)
  const hatch = resolveStyle({ ...style, fillPattern: 'hachure' }, colors, true)
  assert.equal(solid.fill, mixColor(colors['theme:blue'], colors['theme:paper'], 0.14))
  assert.equal(hatch.fill, colors['theme:blue'])
  assert.equal(resolveStyle(DEFAULT_STYLE, colors, true).fill, colors['theme:paper'])
})

test('contrast adjustment keeps already readable colors and produces valid six-digit colors', () => {
  assert.equal(contrastRatio('#000000', '#ffffff'), 21)
  assert.equal(readableColor('#123456', '#ffffff', '#222222'), '#123456')
  for (const background of ['#ffffff', '#191724', '#888888']) {
    const color = readableColor('#999999', background, '#cccccc')
    assert.match(color, /^#[0-9a-f]{6}$/)
    assert.ok(contrastRatio(color, background) >= 4.5)
  }
})
