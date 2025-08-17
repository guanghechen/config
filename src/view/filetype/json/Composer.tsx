import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import type { IPrismThemeScheme } from '@/component/code-highlighter'
import { CodeHighlighter, vscDarkTheme, vscLightTheme } from '@/component/code-highlighter'
import { Json } from '@/component/json'
import { SiteTheme, useSiteViewmodel } from '@/context/site'
import { PRESET_CLASSES } from '@/shared/constant'
import { ModeEnum, useJsonViewViewModel } from './context'
import { DEFAULT_JSON } from './mock-data'

export const Composer: React.FC = () => {
  const siteVM = useSiteViewmodel()
  const theme: SiteTheme = useStateValue(siteVM.theme$)
  const themeScheme: IPrismThemeScheme = theme === SiteTheme.DARKEN ? vscDarkTheme : vscLightTheme

  const viewmodel = useJsonViewViewModel()
  const mode = useStateValue(viewmodel.mode$)
  const content = useStateValue(viewmodel.content$)
  const json = useStateValue(viewmodel.json$)

  const showView: boolean = (mode & ModeEnum.VIEW) !== 0
  const showLiteral: boolean = (mode & ModeEnum.LITERAL) !== 0
  const columns: number = (showView ? 1 : 0) + (showLiteral ? 1 : 0)

  const displayJson = json ?? DEFAULT_JSON

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
              })}
            >
              <Json json={displayJson} />
            </div>
            {columns > 1 && (
              <div className="mx-2 h-full flex-shrink-0 border-r border-gray-300 dark:border-gray-700" />
            )}
          </React.Fragment>
        )}
        {showLiteral && (
          <div
            className={cn(
              'h-full w-[48rem] max-w-[100rem] flex-auto border border-gray-200',
              PRESET_CLASSES.scrollbar,
              {
                'p-2 overflow-auto': columns > 1,
              },
            )}
          >
            <CodeHighlighter
              themeScheme={themeScheme}
              lang="json"
              code={content || ''}
              collapsed={false}
              showLineno={true}
            />
          </div>
        )}
      </div>
    </div>
  )
}

Composer.displayName = 'JsonComposer'
