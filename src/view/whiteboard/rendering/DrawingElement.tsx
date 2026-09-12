import React from 'react'
import { elementBounds, resolveEndpoint, unionBounds } from '@/shared/whiteboard/geometry'
import { connectorPath } from '@/shared/whiteboard/edges'
import { sketchConnector, sketchShape, smoothStroke } from '@/shared/whiteboard/sketch'
import { normalizeAngle } from '@/shared/whiteboard/pose'
import { resolveStyle } from '@/shared/whiteboard/colors'
import { textFont, textLineHeight } from '@/shared/whiteboard/text'
import type { IElement, ILabelElement, INode, IPoint } from '@/shared/whiteboard/model'
import type { BoardTypography } from './typography'
import type { IWhiteboardTheme } from '../theme'

interface IDrawingElementProps {
  element: IElement
  from?: IPoint
  to?: IPoint
  theme: IWhiteboardTheme
  typography: BoardTypography
}

// Each SVG uses world coordinates in its viewBox. DOM order can interleave drawings and rich cards
// without allocating a viewport-sized bitmap for every card boundary.
export const DrawingElement = React.memo<IDrawingElementProps>(
  ({ element, from, to, theme, typography }) => {
    const clipId = React.useId()
    const style = React.useMemo(
      () => resolveStyle(element.style, theme.colors, element.type === 'shape'),
      [element.style, element.type, theme],
    )
    const paths =
      element.type === 'edge'
        ? null
        : element.type === 'stroke'
          ? {
              outline: smoothStroke(element.points, element.width, element.height),
              fill: '',
              hachure: '',
            }
          : sketchShape(
              element.id,
              element.width,
              element.height,
              element.type === 'shape' ? element.shape : 'rectangle',
              element.style.roughness,
              element.style.fillPattern,
            )
    const edge = element.type === 'edge' ? { ...element, from: from!, to: to! } : null
    const map = new Map<string, IElement>()
    const bounds = elementBounds(edge ?? element, map)
    const label =
      (element.type === 'shape' || element.type === 'edge') && element.label
        ? typography.label((edge ?? element) as ILabelElement, map)
        : null
    const area = unionBounds([bounds, ...(label && element.type === 'edge' ? [label.bounds] : [])])!
    const padding = style.strokeWidth + style.roughness * 4 + 3
    const line = edge ? sketchConnector(edge, connectorPath(edge, from!, to!)) : null
    const text =
      element.type === 'text' ? typography.layout(element, element.width - 8, element.height) : null
    const align = style.textAlign ?? (element.type === 'text' ? 'left' : 'center')
    const anchor = align === 'left' ? 'start' : align === 'right' ? 'end' : 'middle'
    const lineHeight = textLineHeight(style, element.type === 'text' ? 'text' : 'label')
    const labelBody = label && (
      <g>
        {element.type === 'edge' && <rect {...label.bounds} fill={theme.canvas} stroke="none" />}
        <text
          fill={style.stroke}
          stroke="none"
          textAnchor={anchor}
          dominantBaseline="central"
          style={{ font: textFont(style, 'label'), whiteSpace: 'pre' }}
        >
          {label.lines.map((value, index) => {
            const box = label.bounds,
              inset = element.type === 'edge' ? 8 : 0
            const x =
              align === 'left'
                ? box.x + inset
                : align === 'right'
                  ? box.x + box.width - inset
                  : box.x + box.width / 2
            return (
              <tspan
                key={index}
                x={x - (element.type === 'edge' ? 0 : element.x)}
                y={
                  box.y +
                  inset +
                  (index + 0.5) * lineHeight -
                  (element.type === 'edge' ? 0 : element.y)
                }
              >
                {value}
              </tspan>
            )
          })}
        </text>
      </g>
    )
    return (
      <svg
        className="wb-vector"
        data-node-id={element.id}
        aria-hidden="true"
        style={{ left: area.x - padding, top: area.y - padding }}
        width={area.width + padding * 2}
        height={area.height + padding * 2}
        viewBox={`${area.x - padding} ${area.y - padding} ${area.width + padding * 2} ${area.height + padding * 2}`}
        fill="none"
        stroke={style.stroke}
        strokeWidth={style.strokeWidth}
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        {edge && line ? (
          <>
            <path
              d={line.body}
              strokeDasharray={
                edge.lineStyle === 'dashed'
                  ? `${style.strokeWidth * 4} ${style.strokeWidth * 3}`
                  : edge.lineStyle === 'dotted'
                    ? `0 ${style.strokeWidth * 3}`
                    : undefined
              }
            />
            <path d={line.heads} />
            {labelBody}
          </>
        ) : (
          element.type !== 'edge' &&
          paths && (
            <g
              transform={`translate(${element.x + element.width / 2} ${element.y + element.height / 2}) rotate(${normalizeAngle(element.rotation ?? 0)}) scale(${element.flipX ? -1 : 1} ${element.flipY ? -1 : 1}) translate(${-element.width / 2} ${-element.height / 2})`}
            >
              {element.type === 'text' && text ? (
                <svg width={element.width} height={element.height} overflow="hidden">
                  <text
                    fill={style.stroke}
                    stroke="none"
                    textAnchor={anchor}
                    dominantBaseline="central"
                    style={{ font: textFont(style, 'text'), whiteSpace: 'pre' }}
                  >
                    {text.lines.map((value, index) => (
                      <tspan
                        key={index}
                        x={
                          align === 'left'
                            ? 4
                            : align === 'right'
                              ? element.width - 4
                              : element.width / 2
                        }
                        y={
                          Math.min(4, Math.max(0, (element.height - text.height) / 2)) +
                          (index + 0.5) * lineHeight
                        }
                      >
                        {value}
                      </tspan>
                    ))}
                  </text>
                </svg>
              ) : (
                <>
                  {style.fillPattern &&
                  style.fillPattern !== 'solid' &&
                  element.type !== 'stroke' ? (
                    <>
                      <defs>
                        <clipPath id={clipId}>
                          <path d={paths.fill} />
                        </clipPath>
                      </defs>
                      <path
                        d={paths.hachure}
                        clipPath={`url(#${clipId})`}
                        stroke={style.fill}
                        strokeWidth={Math.max(0.8, style.strokeWidth * 0.6)}
                      />
                    </>
                  ) : (
                    <path d={paths.fill} fill={style.fill} stroke="none" />
                  )}
                  <path d={paths.outline} />
                  {labelBody}
                </>
              )}
            </g>
          )
        )}
      </svg>
    )
  },
  (a, b) =>
    a.element === b.element &&
    a.theme === b.theme &&
    a.typography === b.typography &&
    a.from?.x === b.from?.x &&
    a.from?.y === b.from?.y &&
    a.to?.x === b.to?.x &&
    a.to?.y === b.to?.y,
)
DrawingElement.displayName = 'WhiteboardDrawingElement'

export const DrawingScene: React.FC<{
  elements: ReadonlyArray<IElement>
  visible: ReadonlyArray<IElement>
  theme: IWhiteboardTheme
  typography: BoardTypography
  card: (element: INode) => React.ReactNode
}> = ({ elements, visible, theme, typography, card }) => {
  const map = new Map(elements.map(element => [element.id, element]))
  return visible.map(element =>
    element.type === 'markdown' || element.type === 'image' ? (
      card(element)
    ) : (
      <DrawingElement
        key={element.id}
        element={element}
        theme={theme}
        typography={typography}
        from={element.type === 'edge' ? resolveEndpoint(element.from, map) : undefined}
        to={element.type === 'edge' ? resolveEndpoint(element.to, map) : undefined}
      />
    ),
  )
}
