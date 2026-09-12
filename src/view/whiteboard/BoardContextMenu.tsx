import React from 'react'
import { BoardIcon, BoardIconLabel } from './BoardIcon'
import { VirtualList } from '@/common/component/virtual-list/VirtualList'
import { canGroup } from '@/shared/whiteboard/organization'
import type { IElement, IPoint } from '@/shared/whiteboard/model'
import type { BoardStore } from './store'
import { elementName } from './elementName'

export const BoardContextMenu: React.FC<{
  position: { x: number; y: number; point: IPoint; targets: IElement[] }
  selected: ReadonlyArray<IElement>
  store: BoardStore
  close: () => void
  copy: (cut?: boolean) => Promise<void>
  paste: (point: IPoint) => Promise<void>
  edit: (element: IElement) => void
}> = ({ position, selected, store, close, copy, paste, edit }) => {
  const ref = React.useRef<HTMLDivElement>(null)
  const editable = store.canEditSelection(),
    removable = store.canRemoveSelection()
  const locked = selected.some(element => store.getSnapshot().locked.has(element.id))
  const top = Math.max(8, Math.min(position.y, window.innerHeight - 520))
  React.useEffect(() => {
    ref.current?.querySelector<HTMLButtonElement>('button:not([disabled])')?.focus()
    const outside = (event: Event): void => {
      if (event.target instanceof Node && !ref.current?.contains(event.target)) close()
    }
    window.addEventListener('pointerdown', outside, true)
    window.addEventListener('resize', close)
    return () => {
      window.removeEventListener('pointerdown', outside, true)
      window.removeEventListener('resize', close)
    }
  }, [close])
  const run = (action: () => void): void => {
    close()
    action()
  }
  return (
    <div
      ref={ref}
      className="wb-context-menu"
      data-wb-ui
      role="menu"
      aria-label="Whiteboard actions"
      style={{
        left: Math.max(8, Math.min(position.x, window.innerWidth - 268)),
        top,
        maxHeight: window.innerHeight - top - 8,
      }}
      onKeyDown={event => {
        event.stopPropagation()
        if (event.key === 'Escape') {
          event.preventDefault()
          close()
        }
        if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
          event.preventDefault()
          const items = [
            ...ref.current!.querySelectorAll<HTMLButtonElement>('button:not([disabled])'),
          ]
          const index = items.indexOf(document.activeElement as HTMLButtonElement)
          items[
            (index + (event.key === 'ArrowDown' ? 1 : -1) + items.length) % items.length
          ]?.focus()
        }
      }}
    >
      <button
        role="menuitem"
        disabled={!selected.length}
        onClick={() =>
          run(() => {
            void copy()
          })
        }
      >
        <BoardIconLabel name="copy">Copy</BoardIconLabel>
      </button>
      <button
        role="menuitem"
        disabled={!removable}
        onClick={() =>
          run(() => {
            void copy(true)
          })
        }
      >
        <BoardIconLabel name="cut">Cut</BoardIconLabel>
      </button>
      <button
        role="menuitem"
        onClick={() =>
          run(() => {
            void paste(position.point)
          })
        }
      >
        <BoardIconLabel name="paste">Paste here</BoardIconLabel>
      </button>
      <button
        role="menuitem"
        disabled={!selected.length}
        onClick={() => run(store.duplicateSelected)}
      >
        <BoardIconLabel name="duplicate">Duplicate</BoardIconLabel>
      </button>
      <button
        role="menuitem"
        disabled={!editable || selected.length !== 1 || selected[0]?.type === 'stroke'}
        onClick={() => run(() => edit(selected[0]))}
      >
        <BoardIconLabel name="edit">Edit content</BoardIconLabel>
      </button>
      <hr />
      <button
        role="menuitem"
        disabled={!editable || !canGroup(selected)}
        onClick={() => run(store.groupSelected)}
      >
        <BoardIconLabel name="group">Group</BoardIconLabel>
      </button>
      <button
        role="menuitem"
        disabled={!editable || !selected.some(element => element.groupId)}
        onClick={() => run(store.ungroupSelected)}
      >
        <BoardIconLabel name="ungroup">Ungroup</BoardIconLabel>
      </button>
      <button
        role="menuitem"
        disabled={!editable}
        onClick={() => run(() => store.reorderSelected('front'))}
      >
        <BoardIconLabel name="front">Bring to front</BoardIconLabel>
      </button>
      <button
        role="menuitem"
        disabled={!editable}
        onClick={() => run(() => store.reorderSelected('back'))}
      >
        <BoardIconLabel name="back">Send to back</BoardIconLabel>
      </button>
      <button
        role="menuitem"
        disabled={!selected.length}
        onClick={() => run(() => store.setSelectedFlags({ locked: !locked }))}
      >
        <BoardIconLabel name={locked ? 'unlock' : 'lock'}>
          {locked ? 'Unlock' : 'Lock'}
        </BoardIconLabel>
      </button>
      <button
        role="menuitem"
        disabled={!selected.length}
        onClick={() =>
          run(() => store.setSelectedFlags({ hidden: !selected.some(element => element.hidden) }))
        }
      >
        <BoardIconLabel name={selected.some(element => element.hidden) ? 'visible' : 'hidden'}>
          {selected.some(element => element.hidden) ? 'Show' : 'Hide'}
        </BoardIconLabel>
      </button>
      <button
        className="wb-danger-action"
        role="menuitem"
        disabled={!removable}
        onClick={() => run(store.removeSelected)}
      >
        <BoardIconLabel name="delete">Delete</BoardIconLabel>
      </button>
      {position.targets.length > 1 && (
        <>
          <hr />
          <p>Select under pointer</p>
          <VirtualList
            items={position.targets}
            itemHeight={30}
            getItemKey={element => element.id}
            style={{ height: Math.min(150, position.targets.length * 30) }}
            renderItem={element => (
              <button
                role="menuitem"
                title={element.id}
                onClick={() => run(() => store.select(new Set([element.id])))}
              >
                <BoardIcon
                  name={
                    element.type === 'shape'
                      ? element.shape
                      : element.type === 'edge'
                        ? 'edge'
                        : element.type
                  }
                />
                <span>
                  {elementName(element)}
                  {store.getSnapshot().locked.has(element.id) ? ' · Locked' : ''}
                </span>
              </button>
            )}
          />
        </>
      )}
    </div>
  )
}
