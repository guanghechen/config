import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { FileTree } from '../container/FileTree'
import { useWorkspaceViewmodel } from '../context'

export const Sidebar: React.FC = () => {
  const viewmodel = useWorkspaceViewmodel()
  const visible: boolean = useStateValue(viewmodel.sidebarVisible$)
  const width: number = useStateValue(viewmodel.sidebarWidth$) // don't subscribe the width change since we adjust it in resizer callback

  const containerRef = React.useRef<HTMLDivElement>(null)
  const resizingRef = React.useRef<boolean>(false)
  const startXRef = React.useRef<number>(0)
  const startWidthRef = React.useRef<number>(0)

  const onResizeStart = React.useCallback((e: React.MouseEvent) => {
    if (containerRef.current) {
      resizingRef.current = true
      startXRef.current = e.clientX
      startWidthRef.current = containerRef.current.offsetWidth
      document.body.classList.add('select-none')
    }
  }, [])

  const onResizeMove = React.useCallback(
    (e: MouseEvent) => {
      if (resizingRef.current) {
        const halfScreenWidth: number = document.documentElement.clientWidth / 2
        const nextWidth: number = startWidthRef.current + (e.clientX - startXRef.current)
        if (nextWidth >= 240 && nextWidth <= halfScreenWidth) {
          if (containerRef.current) containerRef.current.style.width = `${nextWidth}px`
          viewmodel.updateSidebarWidthDebounced(nextWidth)
        }
      }
    },
    [viewmodel],
  )

  const onResizeEnd = React.useCallback(() => {
    if (resizingRef.current) {
      resizingRef.current = false
      document.body.classList.remove('select-none')
    }
  }, [])

  React.useEffect(() => {
    document.addEventListener('mousemove', onResizeMove)
    document.addEventListener('mouseup', onResizeEnd)

    return () => {
      document.removeEventListener('mousemove', onResizeMove)
      document.removeEventListener('mouseup', onResizeEnd)
      document.body.classList.remove('select-none')
    }
  }, [onResizeMove, onResizeEnd])

  return (
    <div
      ref={containerRef}
      className={cn(
        'h-full box-border transition-all duration-300 ease-in-out shadow-lg rounded-lg backdrop-blur-md backdrop-saturate-150 bg-white/70 border-r border-gray-200 text-slate-800 dark:bg-gray-700/80 dark:border-r dark:border-gray-700/30 dark:text-gray-200',
        { 'overflow-hidden border-none p-0': !visible },
      )}
      style={{ width: visible ? width : 0 }}
    >
      <div className="select-none box-border flex h-full w-full flex-col">
        <FileTree />
      </div>
      <div
        className="border-1 absolute right-0 top-0 box-content h-full w-[1px] cursor-col-resize border-b-0 border-t-0 border-solid border-transparent bg-clip-content hover:bg-blue-500 hover:opacity-50"
        onMouseDown={onResizeStart}
      />
    </div>
  )
}

Sidebar.displayName = 'WorkspaceViewSidebar'
