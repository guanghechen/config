import React from 'react'
import { BoardIcon, BoardIconLabel } from './BoardIcon'
import type { IStyle } from '@/shared/whiteboard/model'
import { SketchStylePicker } from './SketchStylePicker'
import { isThemeColor, resolveStyle } from '@/shared/whiteboard/colors'
import type { IThemeColor, IThemeColors } from '@/shared/whiteboard/colors'

const colors: ReadonlyArray<{ token: IThemeColor; label: string }> = [
  { token: 'theme:accent', label: 'Accent' },
  { token: 'theme:red', label: 'Red' },
  { token: 'theme:amber', label: 'Amber' },
  { token: 'theme:green', label: 'Green' },
  { token: 'theme:blue', label: 'Blue' },
  { token: 'theme:purple', label: 'Purple' },
]

export const StyleControls = React.memo<{
  style: IStyle
  colors: IThemeColors
  showSketch: boolean
  showFillPattern: boolean
  showLineWidth?: boolean
  onChange: (patch: Partial<IStyle>) => void
}>(
  ({
    style: displayStyle,
    colors: themeColors,
    showSketch,
    showFillPattern,
    showLineWidth = true,
    onChange: updateStyle,
  }) => {
    const colorId = React.useId()
    const resolved = resolveStyle(displayStyle, themeColors, showFillPattern)
    return (
      <div className="wb-style-controls">
        {(showFillPattern ? (['stroke', 'fill'] as const) : (['stroke'] as const)).map(channel => (
          <div key={channel} className="wb-color-control">
            <div className="wb-color-heading">
              <label htmlFor={`${colorId}-${channel}`}>
                <BoardIconLabel name={channel === 'stroke' ? 'stroke' : 'fill'}>
                  {channel === 'stroke' ? 'Stroke' : 'Fill'}
                </BoardIconLabel>
              </label>
              {channel === 'fill' && (
                <button
                  type="button"
                  className="wb-no-fill"
                  aria-label="No fill"
                  title="No fill"
                  aria-pressed={displayStyle.fill === 'transparent'}
                  onClick={() =>
                    updateStyle({
                      fill: displayStyle.fill === 'transparent' ? 'theme:paper' : 'transparent',
                    })
                  }
                >
                  <BoardIcon name="noFill" />
                </button>
              )}
              <span className="wb-color-mode">
                {isThemeColor(displayStyle[channel]) ? 'Theme' : 'Custom'}
              </span>
              <input
                id={`${colorId}-${channel}`}
                aria-label={channel === 'stroke' ? 'Stroke color' : 'Fill color'}
                type="color"
                value={
                  resolved[channel] === 'transparent'
                    ? themeColors['theme:paper']
                    : resolved[channel]
                }
                onChange={event => updateStyle({ [channel]: event.target.value })}
              />
            </div>
            <div
              className="wb-color-swatches"
              role="group"
              aria-label={`${channel === 'stroke' ? 'Stroke' : 'Fill'} palette`}
            >
              {[
                {
                  token: channel === 'stroke' ? ('theme:ink' as const) : ('theme:paper' as const),
                  label: channel === 'stroke' ? 'Ink' : 'Paper',
                },
                ...colors,
              ].map(({ token, label }) => (
                <button
                  key={token}
                  type="button"
                  aria-label={`${channel === 'stroke' ? 'Stroke' : 'Fill'}: Theme ${label.toLowerCase()}`}
                  title={`${label} · follows site palette`}
                  aria-pressed={displayStyle[channel] === token}
                  style={
                    {
                      '--swatch-color': resolveStyle(
                        { ...displayStyle, [channel]: token },
                        themeColors,
                        showFillPattern,
                      )[channel],
                    } as React.CSSProperties
                  }
                  onClick={() => updateStyle({ [channel]: token })}
                />
              ))}
            </div>
          </div>
        ))}
        {showLineWidth && (
          <div className="wb-field-row">
            <BoardIconLabel name="lineWidth">Line width</BoardIconLabel>
            <div className="wb-segmented" role="group" aria-label="Line width">
              {[1, 2, 4, 8].map(value => (
                <button
                  key={value}
                  aria-label={`Line width: ${value}`}
                  title={`Line width: ${value}`}
                  aria-pressed={displayStyle.strokeWidth === value}
                  onClick={() => updateStyle({ strokeWidth: value })}
                >
                  <svg viewBox="0 0 24 24" aria-hidden="true">
                    <path
                      d="M4 12h16"
                      stroke="currentColor"
                      strokeWidth={value}
                      strokeLinecap="round"
                    />
                  </svg>
                </button>
              ))}
            </div>
          </div>
        )}
        {showSketch && (
          <SketchStylePicker
            style={displayStyle}
            onChange={updateStyle}
            showFillPattern={showFillPattern}
          />
        )}
      </div>
    )
  },
)
StyleControls.displayName = 'WhiteboardStyleControls'
