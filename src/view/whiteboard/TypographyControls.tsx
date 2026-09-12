import React from 'react'
import { BoardIcon, BoardIconLabel } from './BoardIcon'
import { InspectorSection } from './InspectorSection'
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
  const sizeId = React.useId()
  return (
    <InspectorSection title="Text" icon="text" initiallyOpen={kind === 'text'} disabled={disabled}>
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
      <div className="wb-field-row">
        <label htmlFor={sizeId}>
          <BoardIconLabel name="fontSize">Size</BoardIconLabel>
        </label>
        <div className="wb-text-size">
          <input
            id={sizeId}
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
          <button
            aria-label="Bold text"
            title="Bold text"
            aria-pressed={value.fontWeight === 'bold'}
            onClick={() =>
              onChange({ fontWeight: value.fontWeight === 'bold' ? 'normal' : 'bold' })
            }
          >
            <BoardIcon name="bold" />
          </button>
        </div>
      </div>
      <div className="wb-field-row">
        <BoardIconLabel name="textLeft">Align</BoardIconLabel>
        <div className="wb-segmented" role="group" aria-label="Text alignment">
          {(['left', 'center', 'right'] as const).map(align => (
            <button
              key={align}
              aria-label={`Text align ${align}`}
              title={`Align ${align}`}
              aria-pressed={alignment === align}
              onClick={() => onChange({ textAlign: align })}
            >
              <BoardIcon
                name={
                  align === 'left' ? 'textLeft' : align === 'right' ? 'textRight' : 'textCenter'
                }
              />
            </button>
          ))}
        </div>
      </div>
      {automatic !== undefined && (
        <label
          className="wb-check"
          title="Fit content automatically. Resizing a corner switches back to fixed size."
        >
          <BoardIconLabel name="autoSize">Auto size</BoardIconLabel>
          <input
            type="checkbox"
            aria-label="Auto size text"
            checked={automatic}
            onChange={event => onAutomatic(event.target.checked)}
          />
        </label>
      )}
    </InspectorSection>
  )
})
TypographyControls.displayName = 'WhiteboardTypographyControls'
