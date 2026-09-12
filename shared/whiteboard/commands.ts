import { parseDocument } from './document.ts'
import { moveElements } from './geometry.ts'
import { arrangeElements, expandSelection, groupElements, ungroupElements } from './organization.ts'
import { orderedDocument, reorderElements } from './stacking.ts'
import type { IElement, IWhiteboardDocument } from './model.ts'
import type { ILayoutAxis, ILayoutMode } from './organization.ts'
import type { IStackingOrder } from './stacking.ts'
import { flipElements, rotateElements } from './transforms.ts'
import { lockedElements, removalIds, setElementFlags } from './visibility.ts'

const object = (value: unknown): value is Record<string, unknown> =>
  value !== null && typeof value === 'object' && !Array.isArray(value)

const COMMAND_FIELDS: Readonly<Record<string, ReadonlyArray<string>>> = {
  'set-title': ['op', 'title'],
  add: ['op', 'elements'],
  update: ['op', 'id', 'patch'],
  remove: ['op', 'ids'],
  move: ['op', 'ids', 'delta'],
  group: ['op', 'ids', 'groupId'],
  ungroup: ['op', 'ids'],
  arrange: ['op', 'ids', 'axis', 'mode'],
  reorder: ['op', 'ids', 'order'],
  rotate: ['op', 'ids', 'degrees'],
  flip: ['op', 'ids', 'axis'],
  'set-flags': ['op', 'ids', 'locked', 'hidden'],
  'set-regions': ['op', 'regions'],
  'set-presentation': ['op', 'steps'],
}

export function removeElements(
  elements: ReadonlyArray<IElement>,
  ids: ReadonlySet<string>,
): ReadonlyArray<IElement> {
  return elements.filter(
    element =>
      !ids.has(element.id) &&
      !(
        element.type === 'edge' &&
        (ids.has(element.from.nodeId ?? '') || ids.has(element.to.nodeId ?? ''))
      ),
  )
}

export function applyCommands(document: IWhiteboardDocument, input: unknown): IWhiteboardDocument {
  if (
    !object(input) ||
    input.kind !== 'yoz.whiteboard.commands' ||
    input.schemaVersion !== 1 ||
    input.documentId !== document.id ||
    !Array.isArray(input.commands) ||
    input.commands.length > 1000 ||
    Object.keys(input).some(
      key => !['kind', 'schemaVersion', 'documentId', 'commands'].includes(key),
    )
  )
    throw new Error(
      'Expected a version 1 command batch targeting this document ID (at most 1000 commands)',
    )
  let result = orderedDocument(document)
  for (const [index, command] of input.commands.entries()) {
    try {
      if (!object(command) || typeof command.op !== 'string') throw new Error('Missing command op')
      const fields = Object.hasOwn(COMMAND_FIELDS, command.op)
        ? COMMAND_FIELDS[command.op]
        : undefined
      if (!fields) throw new Error(`Unknown command: ${command.op}`)
      if (Object.keys(command).some(key => !fields.includes(key)))
        throw new Error(`Unknown field for ${command.op}`)
      if (command.op === 'set-title') {
        if (typeof command.title !== 'string') throw new Error('title must be a string')
        result = { ...result, title: command.title }
        continue
      }
      if (command.op === 'set-regions') {
        if (!Array.isArray(command.regions)) throw new Error('regions must be an array')
        result = { ...result, regions: command.regions }
        continue
      }
      if (command.op === 'set-presentation') {
        if (!Array.isArray(command.steps)) throw new Error('steps must be an array')
        result = { ...result, presentation: command.steps }
        continue
      }
      if (command.op === 'add') {
        if (!Array.isArray(command.elements)) throw new Error('elements must be an array')
        const protectedIds = lockedElements(result.elements)
        const protectedGroups = new Set(
          result.elements
            .filter(element => protectedIds.has(element.id) && element.groupId)
            .map(element => element.groupId),
        )
        if (
          command.elements.some(
            element =>
              object(element) &&
              typeof element.groupId === 'string' &&
              protectedGroups.has(element.groupId),
          )
        )
          throw new Error('Unlock the target group before adding members')
        result = { ...result, elements: [...result.elements, ...command.elements] }
        continue
      }
      if (command.op === 'update') {
        if (
          typeof command.id !== 'string' ||
          !object(command.patch) ||
          'id' in command.patch ||
          'type' in command.patch
        )
          throw new Error('update requires an id and patch; id/type cannot be changed')
        const current = result.elements.find(element => element.id === command.id)
        if (!current) throw new Error(`Unknown element: ${command.id}`)
        const patch = command.patch
        const protectedIds = lockedElements(result.elements)
        if (
          protectedIds.has(current.id) &&
          Object.keys(patch).some(key => key !== 'locked' && key !== 'hidden')
        )
          throw new Error(`Unlock element or group before editing: ${current.id}`)
        if (
          ('locked' in patch && typeof patch.locked !== 'boolean') ||
          ('hidden' in patch && typeof patch.hidden !== 'boolean')
        )
          throw new Error('locked and hidden must be booleans')
        if (
          patch.groupId !== undefined &&
          result.elements.some(
            element => element.groupId === patch.groupId && protectedIds.has(element.id),
          )
        )
          throw new Error('Unlock the target group before changing membership')
        if (patch.style !== undefined && !object(patch.style))
          throw new Error('style must be an object')
        let base = current
        if (
          current.type === 'edge' &&
          patch.routing !== undefined &&
          patch.routing !== (current.routing ?? 'straight') &&
          !('controls' in patch)
        ) {
          const { controls: _, ...withoutControls } = current
          base = withoutControls
        }
        const updated = {
          ...base,
          ...patch,
          ...((current.type === 'text' || current.type === 'shape') &&
          current.autoSize &&
          (patch.width !== undefined || patch.height !== undefined) &&
          patch.autoSize === undefined
            ? { autoSize: false }
            : {}),
          ...(patch.style ? { style: { ...current.style, ...(patch.style as object) } } : {}),
        } as IElement
        result = {
          ...result,
          elements: result.elements.map(element => (element === current ? updated : element)),
        }
        continue
      }
      if (
        !Array.isArray(command.ids) ||
        !command.ids.length ||
        command.ids.some(id => typeof id !== 'string')
      )
        throw new Error('ids must be a nonempty array of element IDs')
      const ids = new Set<string>(command.ids)
      const known = new Set(result.elements.map(element => element.id))
      for (const id of ids) if (!known.has(id)) throw new Error(`Unknown element: ${id}`)
      const members = expandSelection(result.elements, ids)
      const protectedIds = lockedElements(result.elements)
      if (command.op !== 'set-flags') {
        const affected = command.op === 'remove' ? removalIds(result.elements, ids) : members
        const blocked = [...affected].find(id => protectedIds.has(id))
        if (blocked) throw new Error(`Unlock element or group before editing: ${blocked}`)
      }
      let elements: ReadonlyArray<IElement>
      switch (command.op) {
        case 'set-flags':
          if (
            (!('locked' in command) && !('hidden' in command)) ||
            ('locked' in command && typeof command.locked !== 'boolean') ||
            ('hidden' in command && typeof command.hidden !== 'boolean')
          )
            throw new Error('set-flags requires locked and/or hidden booleans')
          elements = setElementFlags(result.elements, members, {
            ...(typeof command.locked === 'boolean' ? { locked: command.locked } : {}),
            ...(typeof command.hidden === 'boolean' ? { hidden: command.hidden } : {}),
          })
          break
        case 'rotate':
          if (
            typeof command.degrees !== 'number' ||
            !Number.isFinite(command.degrees) ||
            Math.abs(command.degrees) > 1e7
          )
            throw new Error('degrees must be a finite number within ±10000000')
          elements = rotateElements(result.elements, members, command.degrees)
          break
        case 'flip':
          if (command.axis !== 'x' && command.axis !== 'y')
            throw new Error('flip requires axis x or y')
          elements = flipElements(result.elements, members, command.axis)
          break
        case 'remove':
          elements = removeElements(result.elements, ids)
          break
        case 'move': {
          if (
            !object(command.delta) ||
            typeof command.delta.x !== 'number' ||
            !Number.isFinite(command.delta.x) ||
            Math.abs(command.delta.x) > 1e7 ||
            typeof command.delta.y !== 'number' ||
            !Number.isFinite(command.delta.y) ||
            Math.abs(command.delta.y) > 1e7
          )
            throw new Error('delta must contain finite x/y numbers within ±10000000')
          elements = moveElements(result.elements, members, {
            x: command.delta.x,
            y: command.delta.y,
          })
          break
        }
        case 'group':
          if (
            typeof command.groupId !== 'string' ||
            !command.groupId ||
            command.groupId.length > 128
          )
            throw new Error('Provide a nonempty groupId of at most 128 characters')
          if (
            result.elements.some(
              element => element.groupId === command.groupId && !members.has(element.id),
            )
          )
            throw new Error('groupId is already used by elements outside the selection')
          elements = groupElements(result.elements, ids, command.groupId)
          break
        case 'ungroup':
          elements = ungroupElements(result.elements, ids)
          break
        case 'arrange':
          if (
            typeof command.axis !== 'string' ||
            !['x', 'y'].includes(command.axis) ||
            typeof command.mode !== 'string' ||
            !['start', 'center', 'end', 'distribute'].includes(command.mode)
          )
            throw new Error('arrange requires axis x/y and mode start/center/end/distribute')
          elements = arrangeElements(
            result.elements,
            ids,
            command.axis as ILayoutAxis,
            command.mode as ILayoutMode,
          )
          break
        case 'reorder':
          if (
            typeof command.order !== 'string' ||
            !['back', 'backward', 'forward', 'front'].includes(command.order)
          )
            throw new Error('Unknown stacking order')
          elements = reorderElements(result.elements, ids, command.order as IStackingOrder)
          break
        default:
          throw new Error(`Unknown command: ${command.op}`)
      }
      result = { ...result, elements }
    } catch (error) {
      throw new Error(
        `Command ${index + 1}: ${error instanceof Error ? error.message : String(error)}`,
        { cause: error },
      )
    }
  }
  // Validate the entire batch at once, allowing references to elements added later in the batch.
  const validated = parseDocument(JSON.stringify(result))
  return JSON.stringify(validated) === JSON.stringify(document) ? document : validated
}
