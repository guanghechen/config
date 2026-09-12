import React from 'react'
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
        Copy
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
        Cut
      </button>
      <button
        role="menuitem"
        onClick={() =>
          run(() => {
            void paste(position.point)
          })
        }
      >
        Paste here
      </button>
      <button
        role="menuitem"
        disabled={!selected.length}
        onClick={() => run(store.duplicateSelected)}
      >
        Duplicate
      </button>
      <button
        role="menuitem"
        disabled={!editable || selected.length !== 1 || selected[0]?.type === 'stroke'}
        onClick={() => run(() => edit(selected[0]))}
      >
        Edit content
      </button>
      <hr />
      <button
        role="menuitem"
        disabled={!editable || !canGroup(selected)}
        onClick={() => run(store.groupSelected)}
      >
        Group
      </button>
      <button
        role="menuitem"
        disabled={!editable || !selected.some(element => element.groupId)}
        onClick={() => run(store.ungroupSelected)}
      >
        Ungroup
      </button>
      <button
        role="menuitem"
        disabled={!editable}
        onClick={() => run(() => store.reorderSelected('front'))}
      >
        Bring to front
      </button>
      <button
        role="menuitem"
        disabled={!editable}
        onClick={() => run(() => store.reorderSelected('back'))}
      >
        Send to back
      </button>
      <button
        role="menuitem"
        disabled={!selected.length}
        onClick={() => run(() => store.setSelectedFlags({ locked: !locked }))}
      >
        {locked ? 'Unlock' : 'Lock'}
      </button>
      <button
        role="menuitem"
        disabled={!selected.length}
        onClick={() =>
          run(() => store.setSelectedFlags({ hidden: !selected.some(element => element.hidden) }))
        }
      >
        {selected.some(element => element.hidden) ? 'Show' : 'Hide'}
      </button>
      <button role="menuitem" disabled={!removable} onClick={() => run(store.removeSelected)}>
        Delete
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
                {elementName(element)}
                {store.getSnapshot().locked.has(element.id) ? ' · Locked' : ''}
              </button>
            )}
          />
        </>
      )}
    </div>
  )
}
