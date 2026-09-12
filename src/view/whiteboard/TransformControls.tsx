import React from 'react'
import { BoardIconLabel } from './BoardIcon'
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
    <fieldset className="wb-transform-controls" disabled={disabled || !available}>
      <legend>
        <BoardIconLabel name="rotateRight">Transform</BoardIconLabel>
      </legend>
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
      <div className="wb-transform-buttons">
        <button
          aria-label="Rotate −90°"
          title="Rotate −90°"
          onClick={() => store.rotateSelected(-90)}
        >
          <BoardIconLabel name="rotateLeft">−90°</BoardIconLabel>
        </button>
        <button
          aria-label="Rotate +90°"
          title="Rotate +90°"
          onClick={() => store.rotateSelected(90)}
        >
          <BoardIconLabel name="rotateRight">+90°</BoardIconLabel>
        </button>
        <button
          aria-label="Flip horizontal"
          title="Flip horizontal"
          onClick={() => store.flipSelected('x')}
        >
          <BoardIconLabel name="flipHorizontal">Horizontal</BoardIconLabel>
        </button>
        <button
          aria-label="Flip vertical"
          title="Flip vertical"
          onClick={() => store.flipSelected('y')}
        >
          <BoardIconLabel name="flipVertical">Vertical</BoardIconLabel>
        </button>
      </div>
      {available && (
        <p className="wb-endpoint-hint">
          Drag the round handle above the selection to rotate. Shift snaps to 15°. Angled groups
          resize proportionally; external connections stay attached.
        </p>
      )}
    </fieldset>
  )
}
