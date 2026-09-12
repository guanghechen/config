import React from 'react'
import { BoardIcon, BoardIconLabel } from './BoardIcon'
import { InspectorSection } from './InspectorSection'
import { normalizeAngle } from '@/shared/whiteboard/pose'
import { transformBounds } from '@/shared/whiteboard/transforms'
import type { IElement } from '@/shared/whiteboard/model'
import type { BoardStore } from './store'

export const TransformControls: React.FC<{
  selected: ReadonlyArray<IElement>
  store: BoardStore
  disabled: boolean
}> = ({ selected, store, disabled }) => {
  const single = selected.length === 1 && selected[0].type !== 'edge' ? selected[0] : undefined
  const value = single ? Math.round(normalizeAngle(single.rotation ?? 0) * 10) / 10 : 0
  const current = store.getSnapshot()
  const available = !!transformBounds(current.document.elements, current.selected)
  return (
    <InspectorSection title="Transform" icon="rotateRight" disabled={disabled || !available}>
      <label>
        <BoardIconLabel name="rotateRight">{single ? 'Angle' : 'Rotate by'}</BoardIconLabel>
        <input
          key={`${single?.id ?? 'selection'}:${value}`}
          type="number"
          step={15}
          aria-label={single ? 'Rotation angle' : 'Rotate selection by'}
          defaultValue={value}
          onBlur={event => {
            const input = event.currentTarget,
              next = input.valueAsNumber
            if (Number.isFinite(next) && Math.abs(next) <= 1e7) {
              const delta = single
                ? next === value
                  ? 0
                  : normalizeAngle(next - (single.rotation ?? 0))
                : normalizeAngle(next)
              if (delta) store.rotateSelected(delta)
            }
            input.value = String(value)
          }}
          onKeyDown={event => {
            if (event.key === 'Enter') {
              event.preventDefault()
              event.currentTarget.blur()
            }
            if (event.key === 'Escape') {
              event.preventDefault()
              const input = event.currentTarget
              input.value = String(value)
              input.blur()
            }
          }}
        />
      </label>
      <div className="wb-icon-actions" role="group" aria-label="Rotate and flip">
        <button
          aria-label="Rotate −90°"
          title="Rotate −90°"
          onClick={() => store.rotateSelected(-90)}
        >
          <BoardIcon name="rotateLeft" />
        </button>
        <button
          aria-label="Rotate +90°"
          title="Rotate +90°"
          onClick={() => store.rotateSelected(90)}
        >
          <BoardIcon name="rotateRight" />
        </button>
        <button
          aria-label="Flip horizontal"
          title="Flip horizontal"
          onClick={() => store.flipSelected('x')}
        >
          <BoardIcon name="flipHorizontal" />
        </button>
        <button
          aria-label="Flip vertical"
          title="Flip vertical"
          onClick={() => store.flipSelected('y')}
        >
          <BoardIcon name="flipVertical" />
        </button>
      </div>
    </InspectorSection>
  )
}
