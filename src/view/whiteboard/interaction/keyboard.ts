import type React from 'react'
import { moveElements } from '@/shared/whiteboard/geometry'
import type { IElement, IPoint } from '@/shared/whiteboard/model'
import type { BoardStore } from '../store'
import { TOOLS } from './tools'
import type { ITool } from './tools'
import { hasBoardDialog, ownsBoardEvent, typing } from './targets'

const MOVE_DIRECTIONS: Readonly<Record<string, IPoint | undefined>> = {
  arrowleft: { x: -1, y: 0 },
  arrowright: { x: 1, y: 0 },
  arrowup: { x: 0, y: -1 },
  arrowdown: { x: 0, y: 1 },
}

export function boardKeyboard({
  stage,
  store,
  readOnly,
  isDragging,
  isTouchGesture,
  lastPointer,
  moveKeys,
  setSpace,
  scheduleUpdate,
  finishKeyMove,
  finish,
  setTool,
  edit,
  toggleLock,
}: {
  stage: React.RefObject<HTMLDivElement | null>
  store: BoardStore
  readOnly: boolean
  isDragging: () => boolean
  isTouchGesture: () => boolean
  lastPointer: React.RefObject<IPoint | null>
  moveKeys: React.RefObject<Set<string>>
  setSpace: (active: boolean) => void
  scheduleUpdate: (point: IPoint, shift: boolean, alt: boolean) => void
  finishKeyMove: (cancel?: boolean) => void
  finish: (cancel?: boolean) => void
  setTool: (tool: ITool) => void
  edit: (element: IElement) => void
  toggleLock: () => void
}) {
  const keydown = (event: KeyboardEvent): void => {
    if (
      event.defaultPrevented ||
      !ownsBoardEvent(stage.current, event.target) ||
      typing(event.target) ||
      hasBoardDialog(stage.current)
    )
      return
    if (
      (event.key === 'Enter' || event.code === 'Space') &&
      event.target instanceof Element &&
      event.target.closest('button,summary,a')
    )
      return
    const command = event.ctrlKey || event.metaKey
    const key = event.key.toLowerCase()
    if (isTouchGesture()) {
      if (command || MOVE_DIRECTIONS[key]) event.preventDefault()
      return
    }
    if (readOnly) {
      const direction = MOVE_DIRECTIONS[key]
      if (direction && !command) {
        event.preventDefault()
        const camera = store.getSnapshot().camera
        const amount = event.shiftKey ? 100 : 40
        store.camera({
          ...camera,
          x: camera.x - direction.x * amount,
          y: camera.y - direction.y * amount,
        })
      } else if (event.code === 'Space') {
        event.preventDefault()
        setSpace(true)
      } else if (key === 'escape') {
        finish(true)
        setTool('hand')
      } else if (!command && ['h', 'v', 'l'].includes(key)) setTool(key === 'l' ? 'laser' : 'hand')
      else if (command && key === 'a') {
        event.preventDefault()
        const snapshot = store.getSnapshot()
        store.select(
          new Set(
            snapshot.document.elements.filter(e => !snapshot.hidden.has(e.id)).map(e => e.id),
          ),
        )
      } else if (
        (command && ['z', 'y', 'd', 'g', 'x', 'v', '[', ']'].includes(key)) ||
        ['delete', 'backspace', 'enter'].includes(key)
      )
        event.preventDefault()
      return
    }
    if (isDragging() && lastPointer.current && (key === 'shift' || key === 'alt')) {
      event.preventDefault()
      scheduleUpdate(lastPointer.current, event.shiftKey, event.altKey)
      return
    }
    const direction = MOVE_DIRECTIONS[key]
    if (direction && !command && !event.altKey) {
      const snapshot = store.getSnapshot()
      if (isDragging() || !snapshot.selected.size) return
      event.preventDefault()
      if (!store.canEditSelection()) return
      if (event.repeat && !moveKeys.current.has(key)) return
      moveKeys.current.add(key)
      const step = event.shiftKey ? 10 : 1
      store.preview(
        moveElements(snapshot.document.elements, snapshot.selected, {
          x: direction.x * step,
          y: direction.y * step,
        }),
      )
      return
    }
    if (!['shift', 'control', 'meta', 'alt'].includes(key)) finishKeyMove(key === 'escape')
    if (event.code === 'Space') {
      event.preventDefault()
      setSpace(true)
      return
    }
    if (key === 'escape') {
      finish(true)
      setTool('select')
      return
    }
    if (command && key === 'z') {
      event.preventDefault()
      finish(true)
      if (event.shiftKey) store.redo()
      else store.undo()
      return
    }
    if (isDragging()) {
      if (command || key === 'delete' || key === 'backspace') event.preventDefault()
      return
    }
    if (command && key === 'y') {
      event.preventDefault()
      store.redo()
      return
    }
    const snapshot = store.getSnapshot()
    if (command && key === 'a') {
      event.preventDefault()
      store.select(
        new Set(
          snapshot.document.elements
            .filter(item => !snapshot.hidden.has(item.id) && !snapshot.locked.has(item.id))
            .map(item => item.id),
        ),
      )
      return
    }
    if (command && key === 'd') {
      event.preventDefault()
      store.duplicateSelected()
      return
    }
    if (command && key === 'g') {
      event.preventDefault()
      finish(true)
      if (event.shiftKey) store.ungroupSelected()
      else store.groupSelected()
      return
    }
    if (command && !event.altKey && snapshot.selected.size) {
      const backward = event.code === 'BracketLeft' || key === '[' || key === '{'
      const forward = event.code === 'BracketRight' || key === ']' || key === '}'
      if (backward || forward) {
        event.preventDefault()
        store.reorderSelected(
          backward ? (event.shiftKey ? 'back' : 'backward') : event.shiftKey ? 'front' : 'forward',
        )
        return
      }
    }
    if (command && event.shiftKey && key === 'l' && snapshot.selected.size) {
      event.preventDefault()
      store.setSelectedFlags({
        locked: ![...snapshot.selected].some(id => snapshot.locked.has(id)),
      })
      return
    }
    if (key === 'delete' || key === 'backspace') {
      event.preventDefault()
      store.removeSelected()
      return
    }
    if (key === 'enter' && snapshot.selected.size === 1) {
      const node = snapshot.document.elements.find(item => snapshot.selected.has(item.id))
      if (node && node.type !== 'stroke') {
        event.preventDefault()
        edit(node)
      }
    }
    if (!command && !event.altKey) {
      if (key === 'q') {
        event.preventDefault()
        if (!event.repeat) toggleLock()
        return
      }
      const next = TOOLS.find(item => item.key.toLowerCase() === key)
      if (next) setTool(next.id)
    }
  }
  const keyup = (event: KeyboardEvent): void => {
    // A release outside the board must still finish a key move or clear Space-to-pan.
    if (!ownsBoardEvent(stage.current, event.target) && !moveKeys.current.size) {
      setSpace(false)
      return
    }
    if (isDragging() && lastPointer.current && ['Shift', 'Alt'].includes(event.key))
      scheduleUpdate(lastPointer.current, event.shiftKey, event.altKey)
    if (event.code === 'Space') setSpace(false)
    if (moveKeys.current.delete(event.key.toLowerCase()) && !moveKeys.current.size) store.commit()
  }

  return { keydown, keyup }
}
