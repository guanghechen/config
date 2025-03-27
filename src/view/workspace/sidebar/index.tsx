import { css } from '@emotion/css'
import cn from 'clsx'
import React from 'react'
import { ArrowMenuClose, ArrowMenuOpen } from '@/component/icon/material'
import type { WorkspaceViewModel } from '../context'
import { useSidebarVisible, useToggleSidebarVisible } from '../context'
import { FileTree } from './FileTree'
import { Workspace } from './Workspace'

interface IProps {
  readonly viewmodel: WorkspaceViewModel
}

export const WorkspaceSidebar: React.FC<IProps> = props => {
  const { viewmodel } = props

  const visible: boolean = useSidebarVisible()
  const onToggleVisible: () => void = useToggleSidebarVisible()
  const width: number = viewmodel.sidebarWidth$.getSnapshot() // don't subscribe the width change since we adjust it in resizer callback

  const containerRef = React.useRef<HTMLDivElement>(null)
  const resizingRef = React.useRef<boolean>(false)
  const startXRef = React.useRef<number>(0)
  const startWidthRef = React.useRef<number>(0)

  const onResizeStart = React.useCallback(
    (e: React.MouseEvent) => {
      if (containerRef.current) {
        resizingRef.current = true
        startXRef.current = e.clientX
        startWidthRef.current = containerRef.current.offsetWidth
        viewmodel.resizing$.next(true)
      }
    },
    [viewmodel.resizing$],
  )

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
      viewmodel.resizing$.next(false)
    }
  }, [viewmodel.resizing$])

  React.useEffect(() => {
    document.addEventListener('mousemove', onResizeMove)
    document.addEventListener('mouseup', onResizeEnd)

    return () => {
      document.removeEventListener('mousemove', onResizeMove)
      document.removeEventListener('mouseup', onResizeEnd)
      viewmodel.resizing$.next(false)
    }
  }, [onResizeMove, onResizeEnd, viewmodel.resizing$])

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
