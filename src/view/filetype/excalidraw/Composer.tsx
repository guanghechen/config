import cn from 'clsx'
import React from 'react'
import { useScrollToTop } from '@/hook/useScrollToTop'
import { ExcalidrawLayout } from './container/layout'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly mainScrollableContainer: HTMLDivElement | null
}

export const Composer: React.FC<IProps> = props => {
  const { filepathDirtyTick, mainScrollableContainer } = props
  const { visible: visibleScrollToTop, scrollToTop } = useScrollToTop(mainScrollableContainer)

  return (
    <div className="w-full">
      <ExcalidrawLayout filepathDirtyTick={filepathDirtyTick} />
      <button
        onClick={scrollToTop}
        className={cn(
          'cursor-pointer fixed bottom-8 right-8 z-50 flex h-12 w-12 items-center justify-center rounded-full bg-blue-500 bg-opacity-60 text-white shadow-lg transition-all duration-300 hover:bg-blue-600 hover:bg-opacity-100',
          visibleScrollToTop
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

Composer.displayName = 'ExcalidrawComposer'
