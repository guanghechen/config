import React from 'react'
import type { IElement } from '@/shared/whiteboard/model'
import { canGroup, layoutUnits } from '@/shared/whiteboard/organization'
import type { ILayoutAxis, ILayoutMode } from '@/shared/whiteboard/organization'
import type { IStackingOrder } from '@/shared/whiteboard/stacking'
import type { BoardStore } from './store'
import { BoardIcon, BoardIconLabel } from './BoardIcon'
import type { IBoardIconName } from './BoardIcon'

const STACKING: ReadonlyArray<{ order: IStackingOrder; label: string; shortcut: string }> = [
  { order: 'back', label: 'Send to back', shortcut: 'Shift + [' },
  { order: 'backward', label: 'Send backward', shortcut: '[' },
  { order: 'forward', label: 'Bring forward', shortcut: ']' },
  { order: 'front', label: 'Bring to front', shortcut: 'Shift + ]' },
]

const ALIGNMENTS: ReadonlyArray<{
  label: string
  icon: IBoardIconName
  axis: ILayoutAxis
  mode: ILayoutMode
}> = [
  { label: 'Align left', icon: 'alignLeft', axis: 'x', mode: 'start' },
  { label: 'Align horizontal centers', icon: 'alignHorizontalCenter', axis: 'x', mode: 'center' },
  { label: 'Align right', icon: 'alignRight', axis: 'x', mode: 'end' },
  { label: 'Align top', icon: 'alignTop', axis: 'y', mode: 'start' },
  { label: 'Align vertical centers', icon: 'alignVerticalCenter', axis: 'y', mode: 'center' },
  { label: 'Align bottom', icon: 'alignBottom', axis: 'y', mode: 'end' },
]

export const SelectionActions: React.FC<{
  selected: ReadonlyArray<IElement>
  store: BoardStore
  stacking: { backward: boolean; forward: boolean }
}> = ({ selected, store, stacking }) => {
  const units = layoutUnits(selected).length
  const grouped = selected.some(element => element.groupId)
  const groupable = canGroup(selected)
  return (
    <div className="wb-selection-actions">
      <p className="wb-section-heading">
        <BoardIconLabel name="layers">Arrange</BoardIconLabel>
      </p>
      <div className="wb-stacking" role="group" aria-label="Layer order">
        {STACKING.map(({ order, label, shortcut }) => (
          <button
            key={order}
            aria-label={label}
            title={`${label} (Ctrl / ⌘ + ${shortcut})`}
            disabled={
              order === 'back' || order === 'backward' ? !stacking.backward : !stacking.forward
            }
            onClick={() => store.reorderSelected(order)}
          >
            <BoardIcon name={order} />
          </button>
        ))}
      </div>
      {units >= 2 && (
        <div className="wb-align" role="group" aria-label="Align selection">
          {ALIGNMENTS.map(({ label, icon, axis, mode }) => (
            <button
              key={label}
              aria-label={label}
              title={label}
              onClick={() => store.arrangeSelected(axis, mode)}
            >
              <BoardIcon name={icon} />
            </button>
          ))}
        </div>
      )}
      {(units >= 2 || groupable || grouped) && (
        <div className="wb-icon-actions" role="group" aria-label="Distribute and group">
          {units >= 2 && (
            <>
              <button
                aria-label="Distribute horizontally"
                title="Distribute horizontally"
                disabled={units < 3}
                onClick={() => store.arrangeSelected('x', 'distribute')}
              >
                <BoardIcon name="distributeHorizontal" />
              </button>
              <button
                aria-label="Distribute vertically"
                title="Distribute vertically"
                disabled={units < 3}
                onClick={() => store.arrangeSelected('y', 'distribute')}
              >
                <BoardIcon name="distributeVertical" />
              </button>
            </>
          )}
          {groupable && (
            <button
              onClick={store.groupSelected}
              aria-label="Group selection"
              title="Group selection (Ctrl / ⌘ + G)"
            >
              <BoardIcon name="group" />
            </button>
          )}
          {grouped && (
            <button
              onClick={store.ungroupSelected}
              aria-label="Ungroup selection"
              title="Ungroup selection (Ctrl / ⌘ + Shift + G)"
            >
              <BoardIcon name="ungroup" />
            </button>
          )}
        </div>
      )}
    </div>
  )
}
