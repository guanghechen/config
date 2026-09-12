export type ITool =
  | 'select'
  | 'hand'
  | 'rectangle'
  | 'ellipse'
  | 'diamond'
  | 'edge'
  | 'stroke'
  | 'text'
  | 'markdown'
  | 'image'
  | 'eraser'
  | 'laser'

export const TOOLS: ReadonlyArray<{ id: ITool; label: string; key: string; hint: string }> = [
  {
    id: 'select',
    label: 'Select',
    key: 'V',
    hint: 'Drag to select · Alt to move without snapping',
  },
  {
    id: 'laser',
    label: 'Laser pointer',
    key: 'L',
    hint: 'Hold and move to point · Leaves no marks',
  },
  { id: 'hand', label: 'Hand', key: 'H', hint: 'Drag to pan · Ctrl / ⌘ + scroll to zoom' },
  {
    id: 'rectangle',
    label: 'Rectangle',
    key: 'R',
    hint: 'Shift for a square · Alt to draw from center',
  },
  {
    id: 'ellipse',
    label: 'Ellipse',
    key: 'O',
    hint: 'Shift for a circle · Alt to draw from center',
  },
  {
    id: 'diamond',
    label: 'Diamond',
    key: 'D',
    hint: 'Shift for equal sides · Alt to draw from center',
  },
  {
    id: 'edge',
    label: 'Arrow',
    key: 'A',
    hint: 'Drag between blocks to connect · Shift for 45° angles',
  },
  { id: 'stroke', label: 'Freehand', key: 'P', hint: 'Draw freely · Esc to return to selection' },
  {
    id: 'eraser',
    label: 'Eraser',
    key: 'E',
    hint: 'Drag to erase objects or groups · Esc to cancel',
  },
  { id: 'text', label: 'Text', key: 'T', hint: 'Place text · Double-click to edit' },
  {
    id: 'markdown',
    label: 'Markdown',
    key: 'M',
    hint: 'Place a card · Double-click to edit Markdown',
  },
  {
    id: 'image',
    label: 'Image',
    key: 'I',
    hint: 'Choose images · Paste or drop screenshots onto the canvas',
  },
]
