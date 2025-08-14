import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { useScrollToTop } from '@/hook/useScrollToTop'
import { useTextViewViewModel } from './context'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly mainScrollableContainer: HTMLDivElement | null
}

export const Composer: React.FC<IProps> = props => {
  const { mainScrollableContainer } = props
  const viewmodel = useTextViewViewModel()
  const content: string | null = useStateValue(viewmodel.content$)
  const error: string | null = useStateValue(viewmodel.error$)
  const { visible: visibleScrollToTop, scrollToTop } = useScrollToTop(mainScrollableContainer)

  if (error) {
    return (
      <div className="w-full p-8">
        <div className="rounded bg-red-50 p-4 text-red-700">
          <strong>Error:</strong> {error}
        </div>
      </div>
    )
  }

  if (!content) {
    return (
      <div className="w-full p-8">
        <div className="text-gray-500">Loading...</div>
      </div>
    )
  }

  return (
    <div className="w-full">
      <div className="w-full p-8">
        <pre className="font-mono-maple whitespace-pre-wrap break-words text-sm leading-relaxed text-gray-800">
          {content}
        </pre>
      </div>
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

Composer.displayName = 'TextComposer'
