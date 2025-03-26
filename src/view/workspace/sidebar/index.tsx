import { css } from '@emotion/css'
import cn from 'clsx'
import React from 'react'
import { ArrowMenuClose, ArrowMenuOpen } from '@/component/icon/material'
import { useSidebarVisible, useToggleSidebarVisible, useWorkspaceViewmodel } from '../context'
import { FileTree } from './FileTree'
import { Workspace } from './Workspace'

export const WorkspaceSidebar: React.FC = () => {
  const visible: boolean = useSidebarVisible()
  const onToggleVisible: () => void = useToggleSidebarVisible()

  const viewmodel = useWorkspaceViewmodel()
  const width: number = viewmodel.sidebarWidth$.getSnapshot() // don't subscribe the width change since we adjust it in resizer callback

  const containerRef = React.useRef<HTMLDivElement>(null)
  const resizingRef = React.useRef<boolean>(false)
  const startXRef = React.useRef<number>(0)
  const startWidthRef = React.useRef<number>(0)

  const onResizeStart = React.useCallback((e: React.MouseEvent) => {
    if (containerRef.current) {
      resizingRef.current = true
      startXRef.current = e.clientX
      startWidthRef.current = containerRef.current.offsetWidth
      document.body.classList.add('resizing')
    }
  }, [])

  const onResizeMove = React.useCallback(
    (e: MouseEvent) => {
      if (resizingRef.current) {
        const newWidth: number = startWidthRef.current + (e.clientX - startXRef.current)
        const halfWidth = document.documentElement.clientWidth / 2

        if (newWidth >= 240 && newWidth <= halfWidth) {
          if (containerRef.current) containerRef.current.style.width = `${newWidth}px`
          viewmodel.sidebarWidth$.next(newWidth)
        }
      }
    },
    [viewmodel],
  )

  const onResizeEnd = React.useCallback(() => {
    if (resizingRef.current) {
      resizingRef.current = false
      document.body.classList.remove('resizing')
    }
  }, [])

  React.useEffect(() => {
    document.addEventListener('mousemove', onResizeMove)
    document.addEventListener('mouseup', onResizeEnd)

    return () => {
      document.removeEventListener('mousemove', onResizeMove)
      document.removeEventListener('mouseup', onResizeEnd)
      document.body.classList.remove('resizing')
    }
  }, [onResizeMove, onResizeEnd])

  return (
    <div
      ref={containerRef}
      className={cn(
        'h-full box-border transition-all duration-300 ease-in-out',
        classes.container,
        visible ? 'opacity-100' : 'w-0 opacity-0',
      )}
      style={{ width: visible ? width : 0 }}
    >
      <div className="box-border flex h-full w-full flex-col">
        <div className="relative flex w-full flex-initial justify-center bg-neutral-200 dark:bg-neutral-800">
          <Workspace />
          <button
            onClick={onToggleVisible}
            className="absolute right-0 top-2 text-gray-600 hover:text-gray-800 focus:outline-none dark:text-gray-400 dark:hover:text-gray-200"
            title={visible ? 'Hide sidebar' : 'Show sidebar'}
          >
            {visible ? <ArrowMenuClose /> : <ArrowMenuOpen />}
          </button>
        </div>
        <div className="h-0 w-full flex-auto">
          <FileTree />
        </div>
      </div>
      <div
        className="absolute right-[-8px] top-0 box-content h-full w-[1px] cursor-col-resize border-8 border-b-0 border-t-0 border-solid border-transparent bg-clip-content hover:bg-blue-500 hover:opacity-50"
        onMouseDown={onResizeStart}
      />
    </div>
  )
}

WorkspaceSidebar.displayName = 'WorkspaceSidebar'
export default WorkspaceSidebar

const classes = {
  container: css({
    transition: 'width 300ms ease-in-out, opacity 300ms ease-in-out',
    willChange: 'width, opacity',
  }),
}
