import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import type { IPrismThemeScheme } from '@/component/code-highlighter'
import { CodeHighlighter, vscDarkTheme, vscLightTheme } from '@/component/code-highlighter'
import { LiteralBox } from '@/component/LiteralBox'
import { SiteTheme, useSiteViewmodel } from '@/context/site'
import { useTextViewViewModel } from '../context'

export const RawPane: React.FC = () => {
  const site = useSiteViewmodel()
  const theme: SiteTheme = useStateValue(site.theme$)
  const themeScheme: IPrismThemeScheme = theme === SiteTheme.DARKEN ? vscDarkTheme : vscLightTheme

  const viewmodel = useTextViewViewModel()
  const content: string = useStateValue(viewmodel.content$) || ''

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
    <LiteralBox content={content}>
      <CodeHighlighter
        themeScheme={themeScheme}
        lang="text"
        code={content}
        collapsed={false}
        showLineno={true}
      />
    </LiteralBox>
  )
}

RawPane.displayName = 'TextViewRawPane'
