import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Root } from '@yozora/ast'
import React from 'react'
import { useFileResult } from '@/hook/useFileResult'
import { useWorkspaceViewmodel } from '../../context'
import { MarkdownComposer } from './composer'
import { MarkdownModeToggle } from './mode'
import { MarkdownModeEnum } from './types'

export const MarkdownContainer: React.FC = () => {
  const workspaceVM = useWorkspaceViewmodel()
  const workspace: string | null = useStateValue(workspaceVM.workspace$)
  const filepath = useStateValue(workspaceVM.filepath$)
  const tick: number = useStateValue(workspaceVM.filepathDirtyTick$)
  const { data, error } = useFileResult(workspace, filepath, tick)
  const ast: Root | undefined = data?.ast

  const [mode, setMode] = React.useState<MarkdownModeEnum>(MarkdownModeEnum.PREVIEW)
  const [visibleOfScrollToTop, setVisibleOfScrollToTop] = React.useState(false)

  const onModeToggle = React.useCallback(() => {
    setMode(m => (m === MarkdownModeEnum.PREVIEW ? MarkdownModeEnum.AST : MarkdownModeEnum.PREVIEW))
  }, [])

  const onScrollToTop = React.useCallback((): void => {
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }, [])

  React.useEffect(() => {
    const onScroll = (): void => {
      console.log('scrollY: ', window.scrollY)
      if (window.scrollY > 100) setVisibleOfScrollToTop(true)
      else setVisibleOfScrollToTop(false)
    }

    onScroll()
    window.addEventListener('scroll', onScroll)
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  return (
    <div className="relative">
      <div className="relative mb-12 flex-none bg-gray-100 px-2 py-1.5 text-base text-red-500 dark:bg-gray-800 dark:text-red-400">
        <code>error: {String(error)}</code>
      </div>
      {!!ast && (
        <div className="relative">
          <MarkdownModeToggle mode={mode} onToggle={onModeToggle} />
          <MarkdownComposer ast={ast} mode={mode} />
        </div>
      )}
      <button
        onClick={onScrollToTop}
        className={`fixed bottom-8 right-8 z-[9999] flex h-12 w-12 items-center justify-center rounded-full bg-blue-500 text-white shadow-lg transition-all duration-300 hover:bg-blue-600 ${
          visibleOfScrollToTop
            ? 'translate-y-0 opacity-90'
            : 'pointer-events-none translate-y-16 opacity-0'
        }`}
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

MarkdownContainer.displayName = 'MarkdownContainer'
