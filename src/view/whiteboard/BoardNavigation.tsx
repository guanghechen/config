import React from 'react'
import { zoomAt } from '@/shared/whiteboard/geometry'
import type { BoardStore } from './store'
import { BoardIcon } from './BoardIcon'

export const BoardNavigation = React.memo<{
  store: BoardStore
  zoomPercent: number
  size: { width: number; height: number }
  selectedCount: number
  nodeCount: number
  readOnly?: boolean
  status: string
  fit: (selectionOnly?: boolean) => void
}>(({ store, zoomPercent, size, selectedCount, nodeCount, status, fit, readOnly }) => (
  <footer className="wb-bottom" data-wb-ui>
    <div className="wb-zoom">
      <button
        aria-label="Zoom out"
        onClick={() =>
          store.camera(
            zoomAt(
              store.getSnapshot().camera,
              { x: size.width / 2, y: size.height / 2 },
              store.getSnapshot().camera.zoom / 1.25,
            ),
          )
        }
      >
        <BoardIcon name="minus" />
      </button>
      <button
        aria-label="Reset zoom"
        onClick={() =>
          store.camera(
            zoomAt(store.getSnapshot().camera, { x: size.width / 2, y: size.height / 2 }, 1),
          )
        }
      >
        {zoomPercent}%
      </button>
      <button
        aria-label="Zoom in"
        onClick={() =>
          store.camera(
            zoomAt(
              store.getSnapshot().camera,
              { x: size.width / 2, y: size.height / 2 },
              store.getSnapshot().camera.zoom * 1.25,
            ),
          )
        }
      >
        <BoardIcon name="plus" />
      </button>
      <button aria-label="Fit all" title="Fit all" onClick={() => fit()}>
        <BoardIcon name="fit" />
      </button>
      {selectedCount > 0 && (
        <button aria-label="Focus" title="Focus selection" onClick={() => fit(true)}>
          <BoardIcon name="focus" />
        </button>
      )}
    </div>
    <div className="wb-history">
      <button aria-label="Undo" disabled={readOnly} onClick={store.undo}>
        <BoardIcon name="undo" />
      </button>
      <button aria-label="Redo" disabled={readOnly} onClick={store.redo}>
        <BoardIcon name="redo" />
      </button>
    </div>
    <span className="wb-status" role="status">
      {status} · {nodeCount} nodes
    </span>
    <details className="wb-help">
      <summary aria-label="Keyboard shortcuts">
        <BoardIcon name="help" />
      </summary>
      <div>
        Space + drag: pan
        <br />
        Ctrl / ⌘ + scroll: zoom
        <br />
        Two fingers: pan and pinch to zoom
        <br />
        L: laser pointer (hold and move)
        <br />
        Presentation: arrows / Space for steps · Esc to exit
        <br />
        Shift + click: multi-select
        <br />
        Ctrl / ⌘ + click: select underneath
        <br />
        Ctrl / ⌘ + Shift + L: lock / unlock
        <br />
        E: erase objects · Esc: cancel
        <br />
        Drag empty space: select area
        <br />
        Shift + draw: equal sides / 45° arrows
        <br />
        Alt + draw: from center
        <br />
        Alt + move: disable alignment snapping
        <br />
        Q: keep drawing with the same tool
        <br />
        Shift + resize: keep proportions
        <br />
        Arrow keys: move · Shift: 10× step
        <br />
        Double-click / Enter: edit
        <br />
        Drag arrow endpoints: reconnect
        <br />
        Ctrl / ⌘ + D: duplicate
        <br />
        Ctrl / ⌘ + X: cut selection
        <br />
        I: choose images · Paste or drop images
        <br />
        Ctrl / ⌘ + G: group
        <br />
        Ctrl / ⌘ + Shift + G: ungroup
        <br />
        Ctrl / ⌘ + [ / ]: move backward / forward
        <br />
        Ctrl / ⌘ + Shift + [ / ]: send to back / front
        <br />
        Ctrl / ⌘ + Z: undo
        <br />
        Select a card to scroll its content
      </div>
    </details>
  </footer>
))
BoardNavigation.displayName = 'WhiteboardNavigation'
