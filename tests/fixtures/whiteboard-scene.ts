import { DEFAULT_STYLE, createDocument } from '../../shared/whiteboard/model.ts'
import type { IElement, IWhiteboardDocument } from '../../shared/whiteboard/model.ts'

export function createBenchmarkScene(): IWhiteboardDocument {
  const content = [
    '# Architecture\n\nA small service with **clear boundaries**.\n\n- Input validation\n- Immutable state\n- Observable results',
    '# Signal processing\n\n$$\nf(x) = \\int_{-\\infty}^{\\infty} \\hat f(\\xi)e^{2\\pi i x \\xi} d\\xi\n$$\n\nInline: $E = mc^2$.',
    '# Implementation\n\n```typescript\ninterface Node {\n  id: string\n  position: { x: number; y: number }\n}\nconst nodes = new Map<string, Node>()\n```',
    '# Tradeoffs\n\n| Choice | Cost |\n| --- | --- |\n| Canvas | Geometry |\n| DOM | Layout |\n| Cache | Memory |',
    '# Request lifecycle\n\n```mermaid\nflowchart LR\n  Input --> Validate --> Render\n  Validate --> Store\n```',
  ]
  const elements: IElement[] = []
  for (let i = 0; i < 1000; i++) {
    const base = {
      id: `node-${i}`,
      groupId: `group-${Math.floor(i / 5)}`,
      x: i < 5 ? 240 + (i % 3) * 450 : 240 + ((i - 5) % 40) * 420,
      y: i < 5 ? 160 + Math.floor(i / 3) * 340 : 840 + Math.floor((i - 5) / 40) * 340,
      width: 360,
      height: 260,
      style: DEFAULT_STYLE,
    }
    if (i < 5 || i % 5 === 0)
      elements.push({
        ...base,
        type: 'markdown',
        source: { kind: 'inline', content: content[i < 5 ? i : Math.floor(i / 5) % 5] },
      })
    else if (i % 5 === 1)
      elements.push({
        ...base,
        type: 'text',
        text: `Idea ${i}\nDesign a simpler interface\nConnect the next step`,
      })
    else
      elements.push({
        ...base,
        type: 'shape',
        label: `Block ${i}\n模块`,
        shape: i % 3 === 0 ? 'ellipse' : i % 3 === 1 ? 'diamond' : 'rectangle',
        style: {
          ...DEFAULT_STYLE,
          fill: ['#86a98c', '#c7a460', '#9a9ecc'][i % 3],
          fillPattern: (['solid', 'hachure', 'cross-hatch'] as const)[i % 3],
        },
      })
  }
  for (let i = 0; i < 1000; i++)
    elements.push({
      id: `edge-${i}`,
      ...(i % 5 < 4 ? { groupId: `group-${Math.floor(i / 5)}` } : {}),
      type: 'edge',
      label: `flow ${i}`,
      style: DEFAULT_STYLE,
      from: { nodeId: `node-${i}`, x: 1, y: 0.5 },
      to: { nodeId: `node-${(i + 1) % 1000}`, x: 0, y: 0.5 },
    })
  return { ...createDocument(), title: '1000-node mixed benchmark', elements }
}
