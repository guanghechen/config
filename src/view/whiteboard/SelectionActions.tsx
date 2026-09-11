import React from 'react'
import type { IElement } from '@/shared/whiteboard/model'
import { canGroup, layoutUnits } from '@/shared/whiteboard/organization'
import type { ILayoutAxis, ILayoutMode } from '@/shared/whiteboard/organization'
import type { BoardStore } from './store'

const ALIGNMENTS: ReadonlyArray<{
  label: string
  icon: string
  axis: ILayoutAxis
  mode: ILayoutMode
}> = [
  { label: 'Align left', icon: '⇤', axis: 'x', mode: 'start' },
  { label: 'Align horizontal centers', icon: '↔', axis: 'x', mode: 'center' },
  { label: 'Align right', icon: '⇥', axis: 'x', mode: 'end' },
  { label: 'Align top', icon: '⤒', axis: 'y', mode: 'start' },
  { label: 'Align vertical centers', icon: '↕', axis: 'y', mode: 'center' },
  { label: 'Align bottom', icon: '⤓', axis: 'y', mode: 'end' },
]

export const SelectionActions: React.FC<{
  selected: ReadonlyArray<IElement>
  store: BoardStore
}> = ({ selected, store }) => {
  const units = layoutUnits(selected).length
  const grouped = selected.some(element => element.groupId)
  return (
    <div className="wb-selection-actions">
      {canGroup(selected) && (
        <button onClick={store.groupSelected} title="Ctrl / ⌘ + G">
          Group selection
        </button>
      )}
      {grouped && (
        <button onClick={store.ungroupSelected} title="Ctrl / ⌘ + Shift + G">
          Ungroup selection
        </button>
      )}
      {grouped && (
        <p className="wb-endpoint-hint">
          Double-click to edit a member. Ungroup to resize or move it separately.
        </p>
      )}
      {units > 0 && (
        <p className="wb-endpoint-hint">
          Drag corner handles to resize. Hold Shift to keep proportions.
        </p>
      )}
      {units >= 2 && (
        <>
          <div className="wb-align" role="group" aria-label="Align selection">
            {ALIGNMENTS.map(({ label, icon, axis, mode }) => (
              <button
                key={label}
                aria-label={label}
                title={label}
                onClick={() => store.arrangeSelected(axis, mode)}
              >
                {icon}
              </button>
            ))}
          </div>
          <button disabled={units < 3} onClick={() => store.arrangeSelected('x', 'distribute')}>
            Distribute horizontally
          </button>
          <button disabled={units < 3} onClick={() => store.arrangeSelected('y', 'distribute')}>
            Distribute vertically
          </button>
        </>
      )}
    </div>
  )
}
