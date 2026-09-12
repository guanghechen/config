import React from 'react'
import { BoardIconLabel } from '../BoardIcon'
import type { IStyle } from '@/shared/whiteboard/model'
import { sketchShape } from '@/shared/whiteboard/sketch'

const strokes = ['Clean', 'Subtle', 'Sketch', 'Rough'].map((label, roughness) => ({
  label,
  roughness,
  path: sketchShape('style-preview', 40, 22, 'rectangle', roughness / 2).outline,
}))
const fills = (['solid', 'hachure', 'cross-hatch'] as const).map(pattern => ({
  pattern,
  label: { solid: 'Solid', hachure: 'Hachure', 'cross-hatch': 'Cross' }[pattern],
  paths: sketchShape('fill-preview', 40, 22, 'rectangle', 1, pattern),
}))

export const SketchStylePicker = React.memo<{
  style: IStyle
  showFillPattern: boolean
  onChange: (patch: Partial<IStyle>) => void
}>(({ style, showFillPattern, onChange }) => (
  <div className="wb-sketch-style">
    <div className="wb-field-row">
      <BoardIconLabel name="stroke">Roughness</BoardIconLabel>
      <div className="wb-segmented wb-style-options" role="group" aria-label="Hand-drawn">
        {strokes.map(({ label, roughness, path }) => (
          <button
            key={label}
            aria-label={`Hand-drawn: ${label}`}
            title={label}
            aria-pressed={style.roughness === roughness}
            onClick={() => onChange({ roughness })}
          >
            <svg viewBox="-6 -6 52 34" aria-hidden="true">
              <path d={path} fill="none" stroke="currentColor" strokeWidth="1.5" />
            </svg>
          </button>
        ))}
      </div>
    </div>
    {showFillPattern && (
      <div className="wb-field-row">
        <BoardIconLabel name="fill">Shape fill</BoardIconLabel>
        <div className="wb-segmented wb-style-options" role="group" aria-label="Shape fill">
          {fills.map(({ pattern, label, paths }) => (
            <button
              key={pattern}
              aria-label={`Fill pattern: ${pattern}`}
              title={label}
              aria-pressed={(style.fillPattern ?? 'solid') === pattern}
              onClick={() => onChange({ fillPattern: pattern })}
            >
              <svg viewBox="-6 -6 52 34" aria-hidden="true">
                <path
                  d={paths.fill}
                  fill={pattern === 'solid' ? 'currentColor' : 'none'}
                  opacity="0.3"
                />
                <path
                  d={paths.hachure + paths.outline}
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.4"
                />
              </svg>
            </button>
          ))}
        </div>
      </div>
    )}
  </div>
))
SketchStylePicker.displayName = 'WhiteboardSketchStylePicker'
