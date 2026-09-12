import type { IEdge, IPoint, IStyle } from './model.ts'
import { connectorArrowheads } from './edges.ts'
import type { IConnectorPath } from './edges.ts'

export interface ISketchPaths {
  readonly outline: string
  readonly fill: string
  readonly hachure: string
}

function randomFromId(id: string): () => number {
  let seed = 2166136261
  for (let i = 0; i < id.length; i++) seed = Math.imul(seed ^ id.charCodeAt(i), 16777619)
  return () => {
    seed = (Math.imul(seed, 1664525) + 1013904223) | 0
    return (seed >>> 0) / 4294967296
  }
}

const point = (x: number, y: number): string =>
  `${Math.round(x * 100) / 100} ${Math.round(y * 100) / 100}`

function line(
  a: IPoint,
  b: IPoint,
  roughness: number,
  random: () => number,
  pinEnd = false,
): string {
  if (!roughness) return `M${point(a.x, a.y)}L${point(b.x, b.y)}`
  const dx = b.x - a.x,
    dy = b.y - a.y
  const length = Math.hypot(dx, dy)
  const amplitude = Math.min(length * 0.045, roughness * 1.6)
  const jitter = (): number => (random() - 0.5) * amplitude * 2
  const bend = jitter() * 1.3
  const normal = { x: -dy / (length || 1), y: dx / (length || 1) }
  const start = { x: a.x + jitter(), y: a.y + jitter() }
  const end = pinEnd ? b : { x: b.x + jitter(), y: b.y + jitter() }
  return `M${point(start.x, start.y)}C${point(a.x + dx / 3 + normal.x * bend, a.y + dy / 3 + normal.y * bend)} ${point(a.x + (dx * 2) / 3 + normal.x * bend, a.y + (dy * 2) / 3 + normal.y * bend)} ${point(end.x, end.y)}`
}

export function sketchShape(
  id: string,
  width: number,
  height: number,
  shape: 'rectangle' | 'ellipse' | 'diamond',
  roughness: number,
  pattern: IStyle['fillPattern'] = 'solid',
): ISketchPaths {
  const vertices =
    shape === 'diamond'
      ? [
          { x: width / 2, y: 0 },
          { x: width, y: height / 2 },
          { x: width / 2, y: height },
          { x: 0, y: height / 2 },
        ]
      : [
          { x: 0, y: 0 },
          { x: width, y: 0 },
          { x: width, y: height },
          { x: 0, y: height },
        ]
  const fill =
    shape === 'ellipse'
      ? `M${point(width, height / 2)}A${point(width / 2, height / 2)} 0 1 0 ${point(0, height / 2)}A${point(width / 2, height / 2)} 0 1 0 ${point(width, height / 2)}Z`
      : vertices.map((p, index) => `${index ? 'L' : 'M'}${point(p.x, p.y)}`).join('') + 'Z'
  let outline = fill
  if (roughness) {
    const random = randomFromId(`${id}:outline`)
    const paths: string[] = []
    for (const strength of [roughness, roughness * 0.65]) {
      if (shape === 'ellipse') {
        const amplitude = Math.min(width / 20, height / 20, strength * 1.6)
        // Smooth cubic segments keep an ellipse organic without a noisy polygon silhouette.
        const samples = Array.from({ length: 8 }, (_, index) => {
          const angle = (index * Math.PI) / 4
          const rx = width / 2 + (random() - 0.5) * amplitude * 2
          const ry = height / 2 + (random() - 0.5) * amplitude * 2
          return { x: width / 2 + Math.cos(angle) * rx, y: height / 2 + Math.sin(angle) * ry }
        })
        let path = `M${point(samples[0].x, samples[0].y)}`
        for (let index = 0; index < 8; index++) {
          const previous = samples[(index + 7) % 8],
            a = samples[index]
          const b = samples[(index + 1) % 8],
            next = samples[(index + 2) % 8]
          path += `C${point(a.x + (b.x - previous.x) / 6, a.y + (b.y - previous.y) / 6)} ${point(b.x - (next.x - a.x) / 6, b.y - (next.y - a.y) / 6)} ${point(b.x, b.y)}`
        }
        paths.push(path + 'Z')
      } else {
        for (let index = 0; index < vertices.length; index++)
          paths.push(
            line(vertices[index], vertices[(index + 1) % vertices.length], strength, random),
          )
      }
    }
    outline = paths.join('')
  }
  const hachure: string[] = []
  if (pattern !== 'solid') {
    const random = randomFromId(`${id}:fill`)
    // Bound work even for imported nodes spanning millions of world units.
    const spacing = Math.max(10, (width + height) / 160)
    for (const direction of pattern === 'cross-hatch' ? [1, -1] : [1]) {
      for (let offset = spacing / 2; offset < width + height; offset += spacing) {
        const a = { x: Math.max(0, offset - height), y: Math.min(height, offset) }
        const b = { x: Math.min(width, offset), y: Math.max(0, offset - width) }
        if (direction < 0) {
          a.x = width - a.x
          b.x = width - b.x
        }
        hachure.push(line(a, b, roughness * 0.45, random))
      }
    }
  }
  return { outline, fill, hachure: hachure.join('') }
}

// Local coordinates make the cached arrow invariant under translation of both endpoints.
export function sketchArrow(
  id: string,
  to: IPoint,
  roughness: number,
  strokeWidth: number,
): string {
  const random = randomFromId(`${id}:arrow`)
  const angle = Math.atan2(to.y, to.x)
  const size = Math.min(10 + strokeWidth, Math.hypot(to.x, to.y) * 0.45)
  const paths: string[] = []
  for (const strength of roughness ? [roughness, roughness * 0.65] : [0]) {
    paths.push(line({ x: 0, y: 0 }, to, strength, random, true))
    for (const sign of [-1, 1]) {
      paths.push(
        line(
          {
            x: to.x - size * Math.cos(angle + sign * 0.4),
            y: to.y - size * Math.sin(angle + sign * 0.4),
          },
          to,
          strength,
          random,
          true,
        ),
      )
    }
  }
  return paths.join('')
}

export function sketchConnector(
  edge: IEdge,
  path: IConnectorPath,
): { body: string; heads: string } {
  const points = path.points
  const { roughness, strokeWidth } = edge.style
  if (
    points.length === 2 &&
    points[0].x === 0 &&
    points[0].y === 0 &&
    !path.curved &&
    edge.arrowStart !== 'arrow' &&
    edge.arrowEnd !== 'none' &&
    (!edge.lineStyle || edge.lineStyle === 'solid')
  )
    return { body: sketchArrow(edge.id, points[1], roughness, strokeWidth), heads: '' }
  const random = randomFromId(`${edge.id}:connector`)
  const body: string[] = [],
    heads: string[] = []
  for (const strength of roughness ? [roughness, roughness * 0.65] : [0]) {
    if (path.curved) {
      const jitter = (): number => (random() - 0.5) * strength * 3.2
      body.push(
        `M${point(points[0].x, points[0].y)}C${point(points[1].x + jitter(), points[1].y + jitter())} ${point(points[2].x + jitter(), points[2].y + jitter())} ${point(points[3].x, points[3].y)}`,
      )
    } else {
      for (let index = 1; index < points.length; index++)
        body.push(line(points[index - 1], points[index], strength, random, true))
    }
    for (const head of connectorArrowheads(path, strokeWidth, edge.arrowStart, edge.arrowEnd)) {
      heads.push(
        line(head[0], head[1], strength, random, true),
        line(head[2], head[1], strength, random, true),
      )
    }
  }
  return { body: body.join(''), heads: heads.join('') }
}

export function smoothStroke(points: ReadonlyArray<IPoint>, width: number, height: number): string {
  if (!points.length) return ''
  let path = `M${point(points[0].x * width, points[0].y * height)}`
  for (let index = 1; index < points.length - 1; index++) {
    const a = points[index],
      b = points[index + 1]
    path += `Q${point(a.x * width, a.y * height)} ${point(((a.x + b.x) * width) / 2, ((a.y + b.y) * height) / 2)}`
  }
  const last = points[points.length - 1]
  return path + `L${point(last.x * width, last.y * height)}`
}
