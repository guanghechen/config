import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import type { IPrismThemeScheme } from '@/component/code-highlighter'
import { CodeHighlighter, vscDarkTheme, vscLightTheme } from '@/component/code-highlighter'
import { SiteTheme, useSiteViewmodel } from '@/context/site'
import type { IHtmlFileData } from '@/hook/api/file'
import { useHtmlViewViewModel } from '../context'

export const LiteralPane: React.FC = () => {
  const site = useSiteViewmodel()
  const theme: SiteTheme = useStateValue(site.theme$)
  const themeScheme: IPrismThemeScheme = theme === SiteTheme.DARKEN ? vscDarkTheme : vscLightTheme

  const viewmodel = useHtmlViewViewModel()
  const data: IHtmlFileData | null = useStateValue(viewmodel.data$)
  const content: string = data?.content || ''
  const contentError = useStateValue(viewmodel.contentError$)

  if (contentError) {
    return (
      <div className="box-border size-full flex justify-center">
        <div className="flex items-center bg-gray-100 text-red-500 dark:bg-gray-800 dark:text-red-400">
          <code>error: {String(contentError)}</code>
        </div>
      </div>
    )
  }

  if (!content) {
    return (
      <div className="box-border size-full flex justify-center">
        <div className="flex items-center bg-gray-100 text-red-500 dark:bg-gray-800 dark:text-red-400">
          No Content Found
        </div>
      </div>
    )
  }

  return (
    <div className="box-border size-full whitespace-nowrap">
      <CodeHighlighter
        themeScheme={themeScheme}
        lang="html"
        code={content || ''}
        collapsed={false}
        showLineno={true}
      />
    </div>
  )
}

LiteralPane.displayName = 'HtmlViewLiteralPane'
