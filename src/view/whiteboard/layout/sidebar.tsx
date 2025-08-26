import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { WhiteboardCodeEditor } from '../container/CodeEditor'
import { useWhiteboardViewmodel } from '../context'

export const Sidebar: React.FC = () => {
  const viewmodel = useWhiteboardViewmodel()
  const visible: boolean = useStateValue(viewmodel.editorVisible$)
  const width: number = useStateValue(viewmodel.editorWidth$)

  const containerRef = React.useRef<HTMLDivElement>(null)
  const resizingRef = React.useRef<boolean>(false)
  const startXRef = React.useRef<number>(0)
  const startWidthRef = React.useRef<number>(0)

  const onResizeStart = React.useCallback((e: React.MouseEvent) => {
    e.preventDefault()
    e.stopPropagation()
    if (containerRef.current) {
      resizingRef.current = true
      startXRef.current = e.clientX
      startWidthRef.current = containerRef.current.offsetWidth
      document.body.classList.add('select-none')
      document.body.style.cursor = 'col-resize'
    }
  }, [])

  const onResizeMove = React.useCallback(
    (e: MouseEvent) => {
      if (resizingRef.current && containerRef.current) {
        e.preventDefault()
        const screenWidth: number = document.documentElement.clientWidth
        const deltaX: number = e.clientX - startXRef.current
        const nextWidth: number = startWidthRef.current + deltaX

        // Ensure width stays within bounds - allow up to 80% of screen width
        const minWidth = 300
        const maxWidth = screenWidth * 0.8
        const clampedWidth = Math.max(minWidth, Math.min(maxWidth, nextWidth))

        containerRef.current.style.width = `${clampedWidth}px`
        viewmodel.updateEditorWidthDebounced(clampedWidth)
      }
    },
    [viewmodel],
  )

  const onResizeEnd = React.useCallback(() => {
    if (resizingRef.current) {
      resizingRef.current = false
      document.body.classList.remove('select-none')
      document.body.style.cursor = ''
    }
  }, [])

  React.useEffect(() => {
    document.addEventListener('mousemove', onResizeMove)
    document.addEventListener('mouseup', onResizeEnd)

    return () => {
      document.removeEventListener('mousemove', onResizeMove)
      document.removeEventListener('mouseup', onResizeEnd)
      document.body.classList.remove('select-none')
      document.body.style.cursor = ''
    }
  }, [onResizeMove, onResizeEnd])

  return (
    <div
      ref={containerRef}
      className={cn(
        'h-full box-border transition-all duration-300 ease-in-out backdrop-blur-md backdrop-saturate-150 bg-white/70 border-r border-gray-200 text-slate-800 dark:bg-gray-800/70 dark:border-r dark:border-gray-700/30 dark:text-gray-200',
        { 'overflow-hidden': !visible },
      )}
      style={{ width: visible ? width : 0 }}
    >
      <div className="select-none box-border flex h-full w-full flex-col">
        <WhiteboardCodeEditor />
      </div>
      <div
        className="absolute right-[-0.5rem] top-0 z-10 h-full w-1 cursor-col-resize bg-transparent hover:bg-blue-500 hover:opacity-50 active:bg-blue-600"
        onMouseDown={onResizeStart}
      />
    </div>
  )
}

Sidebar.displayName = 'WhiteboardViewSidebar'
