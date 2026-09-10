export interface IVirtualListViewport {
  readonly scrollTop: number
  readonly height: number
  readonly paddingTop: number
  readonly paddingBottom: number
}

export interface IVirtualListRange {
  readonly startIndex: number
  /** Exclusive end of the rendered range. */
  readonly endIndex: number
}

export function getVirtualListRange(
  itemCount: number,
  itemHeight: number,
  overscan: number,
  viewport: IVirtualListViewport,
): IVirtualListRange {
  if (!Number.isFinite(itemHeight) || itemHeight <= 0) {
    throw new RangeError('VirtualList itemHeight must be a positive finite number')
  }
  if (!Number.isInteger(overscan) || overscan < 0) {
    throw new RangeError('VirtualList overscan must be a non-negative integer')
  }

  const totalHeight = itemCount * itemHeight
  const maxScrollTop = Math.max(
    0,
    totalHeight + viewport.paddingTop + viewport.paddingBottom - viewport.height,
  )
  // Data can shrink before the browser reports its clamped scroll position.
  const scrollTop = Math.min(Math.max(0, viewport.scrollTop), maxScrollTop)
  const visibleStart = Math.max(0, scrollTop - viewport.paddingTop)
  const visibleEnd = Math.max(0, scrollTop + viewport.height - viewport.paddingTop)

  return {
    startIndex: Math.min(itemCount, Math.max(0, Math.floor(visibleStart / itemHeight) - overscan)),
    endIndex: Math.min(itemCount, Math.ceil(visibleEnd / itemHeight) + overscan),
  }
}
