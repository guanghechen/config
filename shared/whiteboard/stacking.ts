import { elementLayer } from './model.ts'
import type { IElement } from './model.ts'
import { expandSelection } from './organization.ts'

export type IStackingOrder = 'back' | 'backward' | 'forward' | 'front'

export function stackingDirections(
  elements: ReadonlyArray<IElement>,
  selected: ReadonlySet<string>,
): { backward: boolean; forward: boolean } {
  const members = expandSelection(elements, selected)
  const seenSelected = [false, false, false]
  const seenUnselected = [false, false, false]
  let backward = false,
    forward = false
  for (const element of elements) {
    const layer = elementLayer(element)
    if (members.has(element.id)) {
      backward ||= seenUnselected[layer]
      seenSelected[layer] = true
    } else {
      forward ||= seenSelected[layer]
      seenUnselected[layer] = true
    }
  }
  return { backward, forward }
}

export function reorderElements(
  elements: ReadonlyArray<IElement>,
  selected: ReadonlySet<string>,
  order: IStackingOrder,
): ReadonlyArray<IElement> {
  const members = expandSelection(elements, selected)
  if (!members.size) return elements
  const layers: IElement[][] = [[], [], []]
  for (const element of elements) layers[elementLayer(element)].push(element)
  for (let layer = 0; layer < layers.length; layer++) {
    const items = layers[layer]
    if (order === 'front' || order === 'back') {
      const selectedItems = items.filter(element => members.has(element.id))
      const others = items.filter(element => !members.has(element.id))
      layers[layer] =
        order === 'front' ? [...others, ...selectedItems] : [...selectedItems, ...others]
      continue
    }
    // Traverse against the movement so each selected run crosses only one unselected peer.
    const step = order === 'forward' ? -1 : 1
    for (
      let index = order === 'forward' ? items.length - 2 : 1;
      index >= 0 && index < items.length;
      index += step
    ) {
      const neighbor = index - step
      if (members.has(items[index].id) && !members.has(items[neighbor].id)) {
        ;[items[index], items[neighbor]] = [items[neighbor], items[index]]
      }
    }
  }
  // Preserve slots belonging to other rendering layers, including on no-op commands.
  const cursors = [0, 0, 0]
  const result = elements.map(element => {
    const layer = elementLayer(element)
    const item = layers[layer][cursors[layer]]
    cursors[layer] += 1
    return item
  })
  return result.every((element, index) => element === elements[index]) ? elements : result
}
