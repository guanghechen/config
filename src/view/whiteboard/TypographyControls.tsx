import React from 'react'
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
  return (
    <fieldset className="wb-typography-controls" disabled={disabled}>
      <legend>Text</legend>
      <label>
        Font
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
        Size
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
        Bold
      </label>
      <label>
        Align
        <select
          aria-label="Text alignment"
          value={value.textAlign ?? (kind === 'text' ? 'left' : 'center')}
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
          Auto size
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
