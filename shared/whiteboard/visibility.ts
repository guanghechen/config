import type { IElement } from './model.ts'

export function lockedElements(elements: ReadonlyArray<IElement>): ReadonlySet<string> {
  const groups = new Set<string>()
  for (const element of elements) if (element.locked && element.groupId) groups.add(element.groupId)
  return new Set(
    elements
      .filter(element => element.locked || (element.groupId && groups.has(element.groupId)))
      .map(element => element.id),
  )
}

export function hiddenElements(elements: ReadonlyArray<IElement>): ReadonlySet<string> {
  const hidden = new Set(elements.filter(element => element.hidden).map(element => element.id))
  for (const element of elements)
    if (
      element.type === 'edge' &&
      (hidden.has(element.from.nodeId ?? '') || hidden.has(element.to.nodeId ?? ''))
    )
      hidden.add(element.id)
  return hidden
}

export function changedLockedElement(
  previous: ReadonlyArray<IElement>,
  next: ReadonlyArray<IElement>,
): string | undefined {
  if (!previous.some(element => element.locked)) return undefined
  const locked = lockedElements(previous)
  if (!locked.size) return undefined
  const map = new Map(next.map(element => [element.id, element]))
  for (const element of previous) {
    if (!locked.has(element.id)) continue
    const candidate = map.get(element.id)
    if (
      !candidate ||
      (candidate !== element && JSON.stringify(candidate) !== JSON.stringify(element))
    )
      return element.id
  }
  return undefined
}

export function removalIds(
  elements: ReadonlyArray<IElement>,
  selected: ReadonlySet<string>,
): ReadonlySet<string> {
  const ids = new Set(selected)
  for (const element of elements)
    if (
      element.type === 'edge' &&
      (selected.has(element.from.nodeId ?? '') || selected.has(element.to.nodeId ?? ''))
    )
      ids.add(element.id)
  return ids
}

export function setElementFlags(
  elements: ReadonlyArray<IElement>,
  selected: ReadonlySet<string>,
  flags: { locked?: boolean; hidden?: boolean },
): ReadonlyArray<IElement> {
  const patch = {
    ...(flags.locked !== undefined ? { locked: flags.locked } : {}),
    ...(flags.hidden !== undefined ? { hidden: flags.hidden } : {}),
  }
  return elements.map(element => (selected.has(element.id) ? { ...element, ...patch } : element))
}
