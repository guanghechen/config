import { elementLayer } from './model.ts'
import type { IElement, IWhiteboardDocument } from './model.ts'
import { expandSelection } from './organization.ts'

// Files without the marker used three fixed rendering layers. Migrate once without changing their appearance.
export function orderedDocument(document: IWhiteboardDocument): IWhiteboardDocument {
  if (document.stacking === 'document') return document
  return {
    ...document,
    stacking: 'document',
    elements: [...document.elements].sort((a, b) => elementLayer(a) - elementLayer(b)),
  }
}

export type IStackingOrder = 'back' | 'backward' | 'forward' | 'front'

export function stackingDirections(
  elements: ReadonlyArray<IElement>,
  selected: ReadonlySet<string>,
): { backward: boolean; forward: boolean } {
  const members = expandSelection(elements, selected)
  let seenSelected = false
  let seenUnselected = false
  let backward = false,
    forward = false
  for (const element of elements) {
    if (members.has(element.id)) {
      backward ||= seenUnselected
      seenSelected = true
    } else {
      forward ||= seenSelected
      seenUnselected = true
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
  let result = [...elements]
  if (order === 'front' || order === 'back') {
    const selectedItems = elements.filter(element => members.has(element.id))
    const others = elements.filter(element => !members.has(element.id))
    result = order === 'front' ? [...others, ...selectedItems] : [...selectedItems, ...others]
  } else {
    // Traverse against the movement so each selected run crosses only one unselected peer.
    const step = order === 'forward' ? -1 : 1
    for (
      let index = order === 'forward' ? result.length - 2 : 1;
      index >= 0 && index < result.length;
      index += step
    ) {
      const neighbor = index - step
      if (members.has(result[index].id) && !members.has(result[neighbor].id)) {
        ;[result[index], result[neighbor]] = [result[neighbor], result[index]]
      }
    }
  }
  return result.every((element, index) => element === elements[index]) ? elements : result
}
