import { useEventCallback } from '@guanghechen/react-hooks'
import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { useFileResult } from '@/hook/useFileResult'
import { useWorkspaceViewmodel } from '../../context'
import { JsonComposer } from './composer'
import { JsonModeToggle } from './mode'

const JsonContainer: React.FC = () => {
  const workspaceVM = useWorkspaceViewmodel()
  const workspace: string | null = useStateValue(workspaceVM.workspace$)
  const filepath = useStateValue(workspaceVM.filepath$)
  const tick: number = useStateValue(workspaceVM.filepathDirtyTick$)
  const container = useStateValue(workspaceVM.mainScrollableContainer$)

  const { data, error } = useFileResult(workspace, filepath, tick)

  const [visibleOfScrollToTop, setVisibleOfScrollToTop] = React.useState(false)

  const onScrollToTop = useEventCallback((): void => {
    if (container) container.scrollTo({ top: 0, behavior: 'smooth' })
  })

  React.useEffect(() => {
    if (!container) return

    const onScroll = (): void => {
      if (container.scrollTop > 100) setVisibleOfScrollToTop(true)
      else setVisibleOfScrollToTop(false)
    }

    onScroll()
    container.addEventListener('scroll', onScroll)
    return () => container.removeEventListener('scroll', onScroll)
  }, [container])

  return (
    <div className="relative size-full">
      {!!error && (
        <div className="relative mb-12 flex-none bg-gray-100 px-2 py-1.5 text-base text-red-500 dark:bg-gray-800 dark:text-red-400">
          <code>error: {String(error)}</code>
        </div>
      )}
      {!!data && (
        <div className="relative w-full">
          <JsonModeToggle />
          <JsonComposer json={data} />
        </div>
      )}
      <button
        onClick={onScrollToTop}
        className={cn(
          'cursor-pointer fixed bottom-8 right-8 z-[9999] flex h-12 w-12 items-center justify-center rounded-full bg-blue-500 bg-opacity-60 text-white shadow-lg transition-all duration-300 hover:bg-blue-600 hover:bg-opacity-100',
          visibleOfScrollToTop
            ? 'translate-y-0 opacity-90'
            : 'pointer-events-none translate-y-16 opacity-0',
        )}
        title="Scroll to top"
        aria-label="Scroll to top"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          className="h-6 w-6"
          viewBox="0 0 24 24"
          fill="currentColor"
        >
          <path d="M7.41 15.41L12 10.83l4.59 4.58L18 14l-6-6-6 6z" />
        </svg>
      </button>
    </div>
  )
}

JsonContainer.displayName = 'JsonContainer'

export default React.memo(JsonContainer, () => true)
