import { css } from '@emotion/css'
import cn from 'clsx'
import React from 'react'
import { ArrowMenuClose, ArrowMenuOpen } from '@/component/icon/material'
import { FileTree } from './FileTree'
import { Workspace } from './Workspace'

export const Sidebar: React.FC = () => {
  const [visible, setVisible] = React.useState(true)

  const onToggleVisible = React.useCallback(() => {
    setVisible(prev => !prev)
  }, [])

  const [width, setWidth] = React.useState(256) // Default width (64 * 4 = 256px)
  const containerRef = React.useRef<HTMLDivElement>(null)
  const resizingRef = React.useRef<boolean>(false)
  const startXRef = React.useRef<number>(0)
  const startWidthRef = React.useRef<number>(0)

  const onResizeStart = React.useCallback((e: React.MouseEvent) => {
    if (containerRef.current) {
      resizingRef.current = true
      startXRef.current = e.clientX
      startWidthRef.current = containerRef.current.offsetWidth
      document.addEventListener('mousemove', onResizeMove)
      document.addEventListener('mouseup', onResizeEnd)
    }
  }, [])

  const onResizeMove = React.useCallback((e: MouseEvent) => {
    if (resizingRef.current) {
      const newWidth = startWidthRef.current + (e.clientX - startXRef.current)
      const halfWidth = document.documentElement.clientWidth / 2
      if (newWidth >= 160 && newWidth <= halfWidth) setWidth(newWidth)
    }
  }, [])

  const onResizeEnd = React.useCallback(() => {
    resizingRef.current = false
    document.removeEventListener('mousemove', onResizeMove)
    document.removeEventListener('mouseup', onResizeEnd)
  }, [])

  React.useEffect(() => {
    return () => {
      document.removeEventListener('mousemove', onResizeMove)
      document.removeEventListener('mouseup', onResizeEnd)
    }
  }, [onResizeMove, onResizeEnd])

  return (
    <div
      ref={containerRef}
      className={cn(
        'transition-all duration-300 ease-in-out',
        classes.container,
        visible ? 'opacity-100' : 'w-0 overflow-hidden opacity-0',
      )}
      style={{ width: visible ? `${width}px` : 0 }}
    >
      <div className="relative h-full overflow-auto text-sm">
        <Workspace />
        <FileTree />
      </div>
      <button
        onClick={onToggleVisible}
        className="absolute right-0 top-2 text-gray-600 hover:text-gray-800 focus:outline-none dark:text-gray-400 dark:hover:text-gray-200"
        title={visible ? 'Hide sidebar' : 'Show sidebar'}
      >
        {visible ? <ArrowMenuClose /> : <ArrowMenuOpen />}
      </button>
      <div
        className="absolute right-0 top-0 h-full w-1 cursor-col-resize hover:bg-blue-500 hover:opacity-50"
        onMouseDown={onResizeStart}
      />
    </div>
  )
}
Sidebar.displayName = 'MarkdownSidebar'

const classes = {
  container: css({
    transition: 'width 300ms ease-in-out, opacity 300ms ease-in-out',
    willChange: 'width, opacity',
  }),
}
