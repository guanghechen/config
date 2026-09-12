import { hitTest } from './geometry.ts'
import type { IHitTestOptions } from './geometry.ts'
import { expandSelection } from './organization.ts'
import { hiddenElements, lockedElements, removalIds } from './visibility.ts'
import type { IElement, IPoint } from './model.ts'

export function eraseAlong(
  elements: ReadonlyArray<IElement>,
  from: IPoint,
  to: IPoint,
  zoom: number,
  removed: ReadonlySet<string>,
  options: IHitTestOptions = {},
  labelBounds?: Parameters<typeof hitTest>[4],
): ReadonlySet<string> {
  const result = new Set(removed)
  const locked = options.locked ?? lockedElements(elements)
  const prepared = {
    ...options,
    includeLocked: true,
    locked,
    hidden: options.hidden ?? hiddenElements(elements),
    map: options.map ?? new Map(elements.map(element => [element.id, element])),
    excluded: result,
  }
  const steps = Math.max(
    1,
    Math.min(512, Math.ceil((Math.hypot(to.x - from.x, to.y - from.y) * zoom) / 8)),
  )
  for (let index = 1; index <= steps; index++) {
    const point = {
      x: from.x + ((to.x - from.x) * index) / steps,
      y: from.y + ((to.y - from.y) * index) / steps,
    }
    const hit = hitTest(elements, point, 8 / zoom, false, labelBounds, prepared)
    if (!hit) continue
    const removing = removalIds(elements, expandSelection(elements, new Set([hit.id])))
    if ([...removing].some(id => locked.has(id))) continue
    for (const id of removing) result.add(id)
  }
  return result.size === removed.size ? removed : result
}
