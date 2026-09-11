import { unionBounds } from './geometry.ts'
import type { IBounds, IElement, IPoint } from './model.ts'

export type ILayoutAxis = 'x' | 'y'
export type ILayoutMode = 'start' | 'center' | 'end' | 'distribute'

export function expandSelection(
  elements: ReadonlyArray<IElement>,
  selected: ReadonlySet<string>,
): Set<string> {
  const groups = new Set<string>()
  for (const element of elements) {
    if (selected.has(element.id) && element.groupId) groups.add(element.groupId)
  }
  const result = new Set(selected)
  for (const element of elements) {
    if (element.groupId && groups.has(element.groupId)) result.add(element.id)
  }
  return result
}

export function canGroup(elements: ReadonlyArray<IElement>): boolean {
  return (
    elements.length > 1 &&
    (!elements[0].groupId || elements.some(element => element.groupId !== elements[0].groupId))
  )
}

export function groupElements(
  elements: ReadonlyArray<IElement>,
  selected: ReadonlySet<string>,
  groupId: string,
): ReadonlyArray<IElement> {
  const members = expandSelection(elements, selected)
  if (!canGroup(elements.filter(element => members.has(element.id)))) return elements
  return elements.map(element => (members.has(element.id) ? { ...element, groupId } : element))
}

export function ungroupElements(
  elements: ReadonlyArray<IElement>,
  selected: ReadonlySet<string>,
): ReadonlyArray<IElement> {
  const members = expandSelection(elements, selected)
  return elements.map(element => {
    if (!members.has(element.id) || !element.groupId) return element
    const { groupId: _, ...ungrouped } = element
    return ungrouped
  })
}

interface ILayoutUnit {
  readonly ids: ReadonlyArray<string>
  readonly bounds: IBounds
}

// Edge bounds can reach external nodes. Only node boxes determine a group's layout footprint.
export function layoutUnits(elements: ReadonlyArray<IElement>): ILayoutUnit[] {
  const groups = new Map<string, IElement[]>()
  const batches: IElement[][] = []
  for (const element of elements) {
    const group = element.groupId ? groups.get(element.groupId) : undefined
    if (group) group.push(element)
    else {
      const batch = [element]
      batches.push(batch)
      if (element.groupId) groups.set(element.groupId, batch)
    }
  }
  const units: ILayoutUnit[] = []
  for (const batch of batches) {
    const bounds = unionBounds(batch.filter(element => element.type !== 'edge'))
    if (bounds) units.push({ ids: batch.map(element => element.id), bounds })
  }
  return units
}

export function arrangeElements(
  elements: ReadonlyArray<IElement>,
  selected: ReadonlySet<string>,
  axis: ILayoutAxis,
  mode: ILayoutMode,
): ReadonlyArray<IElement> {
  const members = expandSelection(elements, selected)
  const units = layoutUnits(elements.filter(element => members.has(element.id)))
  if (units.length < (mode === 'distribute' ? 3 : 2)) return elements
  const size = axis === 'x' ? 'width' : 'height'
  const deltas = new Map<string, IPoint>()
  const bounds = unionBounds(units.map(unit => unit.bounds))!
  units.sort((a, b) => a.bounds[axis] - b.bounds[axis])
  const first = units[0].bounds,
    last = units[units.length - 1].bounds
  const gap =
    (last[axis] +
      last[size] -
      first[axis] -
      units.reduce((sum, unit) => sum + unit.bounds[size], 0)) /
    (units.length - 1)
  let cursor = first[axis]
  for (let index = 0; index < units.length; index++) {
    const unit = units[index]
    let target: number
    if (mode === 'distribute') {
      target = index === 0 || index === units.length - 1 ? unit.bounds[axis] : cursor
      cursor += unit.bounds[size] + gap
    } else {
      const fraction = mode === 'start' ? 0 : mode === 'center' ? 0.5 : 1
      target = bounds[axis] + (bounds[size] - unit.bounds[size]) * fraction
    }
    const delta = { x: 0, y: 0, [axis]: target - unit.bounds[axis] }
    for (const id of unit.ids) deltas.set(id, delta)
  }
  return elements.map(element => {
    const delta = deltas.get(element.id)
    if (!delta || (!delta.x && !delta.y)) return element
    if (element.type !== 'edge')
      return { ...element, x: element.x + delta.x, y: element.y + delta.y }
    return {
      ...element,
      from: element.from.nodeId
        ? element.from
        : { x: element.from.x + delta.x, y: element.from.y + delta.y },
      to: element.to.nodeId ? element.to : { x: element.to.x + delta.x, y: element.to.y + delta.y },
    }
  })
}
