import React from 'react'
import type { IBounds } from '@/shared/whiteboard/model'
import { elementBounds, intersects } from '@/shared/whiteboard/geometry'
import type { IAlignmentGuide } from '@/shared/whiteboard/drawing'
import type { ITransformFrame } from '@/shared/whiteboard/pose'
import type { IBoardSnapshot } from '../store'
import type { IWhiteboardTheme } from '../theme'
import { CanvasRenderer, visibleBounds } from './renderer'
import type { BoardTypography } from './typography'

export function useBoardRenderer({
  snapshot,
  theme,
  typography,
  size,
  readOnly,
  marquee,
  guides,
  rotationPreview,
}: {
  snapshot: IBoardSnapshot
  theme: IWhiteboardTheme
  typography: BoardTypography
  size: { width: number; height: number }
  readOnly: boolean
  marquee?: IBounds
  guides: ReadonlyArray<IAlignmentGuide>
  rotationPreview?: ITransformFrame
}) {
  const [renderer] = React.useState(() => new CanvasRenderer(theme, typography))
  const drawing = React.useRef<HTMLCanvasElement>(null)
  const overlay = React.useRef<HTMLCanvasElement>(null)
  React.useLayoutEffect(() => {
    if (!drawing.current || !overlay.current) return
    renderer.setTheme(theme)
    if (snapshot.camera.zoom < 0.35)
      renderer.draw(
        drawing.current,
        snapshot.document.elements,
        snapshot.camera,
        size.width,
        size.height,
      )
    renderer.drawSelection(
      overlay.current,
      snapshot.document.elements,
      snapshot.camera,
      readOnly ? new Set() : snapshot.selected,
      size.width,
      size.height,
      marquee,
      guides,
      rotationPreview,
    )
  }, [renderer, snapshot, size, marquee, guides, rotationPreview, theme, readOnly])
  React.useEffect(() => {
    const timer = setTimeout(() => {
      if (!drawing.current || snapshot.camera.zoom >= 0.35) return
      renderer.invalidate()
      renderer.draw(
        drawing.current,
        snapshot.document.elements,
        snapshot.camera,
        size.width,
        size.height,
      )
    }, 180)
    return () => clearTimeout(timer)
  }, [renderer, snapshot.document.elements, snapshot.camera, size])
  React.useEffect(() => () => renderer.dispose(), [renderer])
  const visible = visibleBounds(snapshot.camera, size.width, size.height)
  // Keep the grid 16–32 screen pixels apart; dense overview dots otherwise dominate raster work.
  const gridSpacing =
    24 * snapshot.camera.zoom * 2 ** Math.ceil(Math.log2(16 / (24 * snapshot.camera.zoom)))
  const elementMap = new Map(snapshot.document.elements.map(element => [element.id, element]))
  const visibleElements =
    snapshot.camera.zoom < 0.35
      ? []
      : snapshot.document.elements.filter(
          item =>
            !snapshot.hidden.has(item.id) && intersects(elementBounds(item, elementMap), visible),
        )
  return { drawing, overlay, visible, visibleElements, gridSpacing }
}
