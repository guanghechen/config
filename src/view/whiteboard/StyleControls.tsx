import React from 'react'
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
    const resolved = resolveStyle(displayStyle, themeColors, showFillPattern)
    return (
      <>
        {(showFillPattern ? (['stroke', 'fill'] as const) : (['stroke'] as const)).map(channel => (
          <div key={channel} className="wb-color-control">
            <label>
              {channel === 'stroke' ? 'Stroke' : 'Fill'}
              <span className="wb-color-mode">
                {isThemeColor(displayStyle[channel]) ? 'Theme' : 'Custom'}
              </span>
              <input
                aria-label={channel === 'stroke' ? 'Stroke color' : 'Fill color'}
                type="color"
                value={
                  resolved[channel] === 'transparent'
                    ? themeColors['theme:paper']
                    : resolved[channel]
                }
                onChange={event => updateStyle({ [channel]: event.target.value })}
              />
            </label>
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
        {showFillPattern && (
          <label className="wb-check">
            <input
              type="checkbox"
              checked={displayStyle.fill === 'transparent'}
              onChange={event =>
                updateStyle({ fill: event.target.checked ? 'transparent' : 'theme:paper' })
              }
            />
            No fill
          </label>
        )}
        {showLineWidth && (
          <label>
            Line width
            <select
              aria-label="Line width"
              value={displayStyle.strokeWidth}
              onChange={event => updateStyle({ strokeWidth: Number(event.target.value) })}
            >
              {[1, 2, 4, 8].map(value => (
                <option key={value}>{value}</option>
              ))}
            </select>
          </label>
        )}
        {showSketch && (
          <SketchStylePicker
            style={displayStyle}
            onChange={updateStyle}
            showFillPattern={showFillPattern}
          />
        )}
      </>
    )
  },
)
StyleControls.displayName = 'WhiteboardStyleControls'
