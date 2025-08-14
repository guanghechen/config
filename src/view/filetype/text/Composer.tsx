import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import type { IPrismThemeScheme } from '@/component/code-highlighter'
import { CodeHighlighter, vscDarkTheme, vscLightTheme } from '@/component/code-highlighter'
import { PRESET_CLASSES } from '@/constant/classes'
import { SiteTheme, useSiteViewmodel } from '@/context/site'
import { useScrollToTop } from '@/hook/useScrollToTop'
import { ModeEnum, useTextViewViewModel } from './context'
import { TransformMode } from './container/TransformMode'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly mainScrollableContainer: HTMLDivElement | null
}

export const Composer: React.FC<IProps> = props => {
  const { mainScrollableContainer } = props
  const siteVM = useSiteViewmodel()
  const theme: SiteTheme = useStateValue(siteVM.theme$)
  const themeScheme: IPrismThemeScheme = theme === SiteTheme.DARKEN ? vscDarkTheme : vscLightTheme

  const viewmodel = useTextViewViewModel()
  const mode = useStateValue(viewmodel.mode$)
  const content: string | null = useStateValue(viewmodel.content$)
  const error: string | null = useStateValue(viewmodel.error$)
  const { visible: visibleScrollToTop, scrollToTop } = useScrollToTop(mainScrollableContainer)

  const showView: boolean = (mode & ModeEnum.VIEW) !== 0
  const showRaw: boolean = (mode & ModeEnum.RAW) !== 0
  const showTransform: boolean = (mode & ModeEnum.TRANSFORM) !== 0
  const columns: number = (showView ? 1 : 0) + (showRaw ? 1 : 0) + (showTransform ? 1 : 0)

  if (error) {
    return (
      <div className="w-full p-8">
        <div className="rounded bg-red-50 p-4 text-red-700 dark:bg-red-900 dark:text-red-300">
          <strong>Error:</strong> {error}
        </div>
      </div>
    )
  }

  if (!content) {
    return (
      <div className="w-full p-8">
        <div className="text-gray-500 dark:text-gray-400">Loading...</div>
      </div>
    )
  }

  return (
    <div className="w-full">
      <div
        className={cn('flex w-full items-start justify-center', {
          'h-[calc(100vh-7rem)]': columns > 1,
        })}
      >
        {showView && (
          <React.Fragment>
            <div
              className={cn('h-full w-[72rem] max-w-[100rem] flex-auto', PRESET_CLASSES.scrollbar, {
                'p-2 overflow-auto': columns > 1,
                'p-8': columns === 1,
              })}
            >
              <pre className="font-mono-maple whitespace-pre-wrap break-words text-sm leading-relaxed text-gray-800 dark:text-gray-200">
                {content}
              </pre>
            </div>
            {columns > 1 && (
              <div className="mx-2 h-full flex-shrink-0 border-r border-gray-300 dark:border-gray-700" />
            )}
          </React.Fragment>
        )}
        {showRaw && (
          <React.Fragment>
            {columns > 1 && (
              <div className="mx-2 h-full flex-shrink-0 border-r border-gray-300 dark:border-gray-700" />
            )}
            <div
              className={cn(
                'h-full w-[48rem] max-w-[100rem] flex-auto border border-gray-200',
                PRESET_CLASSES.scrollbar,
                {
                  'p-2 overflow-auto': columns > 1,
                  'p-8 overflow-auto': columns === 1,
                },
              )}
            >
              <div className="overflow-x-auto whitespace-nowrap">
                <CodeHighlighter
                  themeScheme={themeScheme}
                  lang="text"
                  code={content}
                  collapsed={false}
                  showLineno={true}
                />
              </div>
            </div>
          </React.Fragment>
        )}
        {showTransform && (
          <React.Fragment>
            {columns > 1 && (
              <div className="mx-2 h-full flex-shrink-0 border-r border-gray-300 dark:border-gray-700" />
            )}
            <div
              className={cn(
                'h-full w-[48rem] max-w-[100rem] flex-auto border border-gray-200',
                PRESET_CLASSES.scrollbar,
                {
                  'p-2 overflow-auto': columns > 1,
                  'overflow-auto': columns === 1,
                },
              )}
            >
              <TransformMode />
            </div>
          </React.Fragment>
        )}
      </div>
      <button
        onClick={scrollToTop}
        className={cn(
          'cursor-pointer fixed bottom-8 right-8 z-50 flex h-12 w-12 items-center justify-center rounded-full bg-blue-500 bg-opacity-60 text-white shadow-lg transition-all duration-300 hover:bg-blue-600 hover:bg-opacity-100 dark:bg-blue-600 dark:bg-opacity-70 dark:hover:bg-blue-500 dark:hover:bg-opacity-100',
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
