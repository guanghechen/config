import React from 'react'
import { BoardIconLabel } from './BoardIcon'
import { textSize } from '@/shared/whiteboard/text'
import type { ITextKind, ITextStyle } from '@/shared/whiteboard/text'

export const TypographyControls = React.memo<{
  value: ITextStyle
  kind: ITextKind
  disabled: boolean
  automatic?: boolean
  onChange: (patch: ITextStyle) => void
  onAutomatic: (automatic: boolean) => void
}>(({ value, kind, disabled, automatic, onChange, onAutomatic }) => {
  const size = textSize(value, kind)
  const alignment = value.textAlign ?? (kind === 'text' ? 'left' : 'center')
  return (
    <fieldset className="wb-typography-controls" disabled={disabled}>
      <legend>
        <BoardIconLabel name="text">Text</BoardIconLabel>
      </legend>
      <label>
        <BoardIconLabel name="text">Font</BoardIconLabel>
        <select
          aria-label="Text font"
          value={value.fontFamily ?? (kind === 'text' ? 'hand' : 'mono')}
          onChange={event =>
            onChange({ fontFamily: event.target.value as ITextStyle['fontFamily'] })
          }
        >
          <option value="hand">Handwritten</option>
          <option value="sans">Sans serif</option>
          <option value="mono">Monospace</option>
        </select>
      </label>
      <label>
        <BoardIconLabel name="fontSize">Size</BoardIconLabel>
        <input
          key={size}
          type="number"
          aria-label="Text size"
          min={8}
          max={200}
          step={1}
          defaultValue={size}
          onBlur={event => {
            const input = event.currentTarget,
              next = input.valueAsNumber
            if (Number.isFinite(next) && next >= 8 && next <= 200) {
              if (next !== size) onChange({ fontSize: next })
            } else input.value = String(size)
          }}
          onKeyDown={event => {
            if (event.key === 'Enter') {
              event.preventDefault()
              event.currentTarget.blur()
            }
            if (event.key === 'Escape') {
              event.preventDefault()
              const input = event.currentTarget
              input.value = String(size)
              input.blur()
            }
          }}
        />
      </label>
      <label className="wb-check">
        <input
          type="checkbox"
          aria-label="Bold text"
          checked={value.fontWeight === 'bold'}
          onChange={event => onChange({ fontWeight: event.target.checked ? 'bold' : 'normal' })}
        />
        <BoardIconLabel name="bold">Bold</BoardIconLabel>
      </label>
      <label>
        <BoardIconLabel
          name={
            alignment === 'left' ? 'textLeft' : alignment === 'right' ? 'textRight' : 'textCenter'
          }
        >
          Align
        </BoardIconLabel>
        <select
          aria-label="Text alignment"
          value={alignment}
          onChange={event => onChange({ textAlign: event.target.value as ITextStyle['textAlign'] })}
        >
          <option value="left">Left</option>
          <option value="center">Center</option>
          <option value="right">Right</option>
        </select>
      </label>
      {automatic !== undefined && (
        <label className="wb-check">
          <input
            type="checkbox"
            aria-label="Auto size text"
            checked={automatic}
            onChange={event => onAutomatic(event.target.checked)}
          />
          <BoardIconLabel name="autoSize">Auto size</BoardIconLabel>
        </label>
      )}
      {automatic && (
        <p className="wb-endpoint-hint">
          Fits content as it changes. Resizing a corner switches back to fixed size.
        </p>
      )}
    </fieldset>
  )
})
TypographyControls.displayName = 'WhiteboardTypographyControls'
