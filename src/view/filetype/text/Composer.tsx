import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import type { IPrismThemeScheme } from '@/component/code-highlighter'
import { vscDarkTheme, vscLightTheme } from '@/component/code-highlighter'
import { SiteTheme, useSiteViewmodel } from '@/context/site'
import { useScrollToTop } from '@/hook/useScrollToTop'
import type { ITextTransformedNode } from '@/shared/transform/types'
import { ModeEnum, useTextViewViewModel } from './context'
import type { ViewModeEnum } from './context/types'
import { RawPane } from './layout/RawPane'
import { TransformPane } from './layout/TransformPane'
import { ViewPane } from './layout/ViewPane'

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
  const viewMode: ViewModeEnum = useStateValue(viewmodel.viewMode$)
  const content: string | null = useStateValue(viewmodel.content$)
  const error: string | null = useStateValue(viewmodel.error$)
  const transformedNodes: ITextTransformedNode[] | null = useStateValue(viewmodel.transformedNodes$)
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
            <ViewPane
              content={content}
              viewMode={viewMode}
              transformedNodes={transformedNodes}
              columns={columns}
            />
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
            <RawPane content={content} themeScheme={themeScheme} columns={columns} />
          </React.Fragment>
        )}
        {showTransform && (
          <React.Fragment>
            {columns > 1 && (
              <div className="mx-2 h-full flex-shrink-0 border-r border-gray-300 dark:border-gray-700" />
            )}
            <TransformPane columns={columns} />
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
