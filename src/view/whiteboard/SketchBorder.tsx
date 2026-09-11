import React from 'react'
import { sketchShape } from '@/shared/whiteboard/sketch'
import type { IStyle } from '@/shared/whiteboard/model'

export const SketchBorder = React.memo<{
  id: string
  width: number
  height: number
  style: IStyle
}>(({ id, width, height, style }) => {
  const outline = React.useMemo(
    () => sketchShape(id, width, height, 'rectangle', style.roughness).outline,
    [id, width, height, style.roughness],
  )
  return (
    <svg
      className="wb-sketch-border"
      width={width}
      height={height}
      style={{ left: -style.strokeWidth, top: -style.strokeWidth }}
      aria-hidden="true"
    >
      <path
        d={outline}
        fill="none"
        stroke={style.stroke}
        strokeWidth={style.strokeWidth}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  )
})
SketchBorder.displayName = 'WhiteboardSketchBorder'
