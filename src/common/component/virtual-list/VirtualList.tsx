import React from 'react'
import { flushSync } from 'react-dom'
import type { IVirtualListViewport } from './range'
import { getVirtualListRange } from './range'

export interface IVirtualListProps<TItem> {
  readonly items: readonly TItem[]
  /** Fixed row height in pixels. */
  readonly itemHeight: number
  readonly overscan?: number
  readonly getItemKey: (item: TItem, index: number) => React.Key
  readonly renderItem: (item: TItem, index: number) => React.ReactNode
  readonly className?: string
  /** The scroll container needs a bounded height through style or className. */
  readonly style?: React.CSSProperties
}

export const VirtualList = <TItem,>(props: IVirtualListProps<TItem>): React.ReactElement => {
  const { items, itemHeight, overscan = 5, getItemKey, renderItem, className, style } = props
  const [viewport, setViewport] = React.useState<IVirtualListViewport>({
    scrollTop: 0,
    height: 0,
    paddingTop: 0,
    paddingBottom: 0,
  })

  const elementRef = React.useRef<HTMLDivElement | null>(null)
  const measureViewport = React.useCallback((): void => {
    const element = elementRef.current
    if (element === null) return

    const computedStyle = window.getComputedStyle(element)
    const scrollTop = element.scrollTop
    const height = element.clientHeight
    const paddingTop = Number.parseFloat(computedStyle.paddingTop)
    const paddingBottom = Number.parseFloat(computedStyle.paddingBottom)

    setViewport(previous =>
      previous.scrollTop === scrollTop &&
      previous.height === height &&
      previous.paddingTop === paddingTop &&
      previous.paddingBottom === paddingBottom
        ? previous
        : { scrollTop, height, paddingTop, paddingBottom },
    )
  }, [])

  const scrollRef = React.useCallback(
    (element: HTMLDivElement | null) => {
      elementRef.current = element
      if (element === null) return

      measureViewport()
      const observer = new ResizeObserver(measureViewport)
      observer.observe(element)
      // The spacer also changes size when filtering or collapsing a tree.
      if (element.firstElementChild !== null) observer.observe(element.firstElementChild)
      const onScroll = (): void => {
        // Commit the new rows before paint when scrolling beyond the overscan range.
        flushSync(measureViewport)
      }
      element.addEventListener('scroll', onScroll, { passive: true })

      return () => {
        observer.disconnect()
        element.removeEventListener('scroll', onScroll)
        elementRef.current = null
      }
    },
    [measureViewport],
  )

  // Padding can change without changing either observed content box, including
  // when top and bottom padding trade places. Measure after each React commit.
  React.useLayoutEffect(measureViewport)

  const { startIndex, endIndex } = getVirtualListRange(items.length, itemHeight, overscan, viewport)
  const rows: React.ReactElement[] = []
  for (let index = startIndex; index < endIndex; index++) {
    const item = items[index]
    rows.push(
      <div
        key={getItemKey(item, index)}
        style={{
          position: 'absolute',
          top: 0,
          left: 0,
          width: '100%',
          height: itemHeight,
          boxSizing: 'border-box',
          transform: `translateY(${index * itemHeight}px)`,
        }}
      >
        {renderItem(item, index)}
      </div>,
    )
  }

  return (
    <div
      ref={scrollRef}
      className={className}
      style={{ overflow: 'auto', overflowAnchor: 'none', ...style }}
    >
      <div style={{ height: items.length * itemHeight, position: 'relative' }}>{rows}</div>
    </div>
  )
}
VirtualList.displayName = 'VirtualList'
