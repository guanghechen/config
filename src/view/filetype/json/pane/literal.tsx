import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import type { IPrismThemeScheme } from '@/common/component/code-highlighter'
import { CodeHighlighter, getPrismTheme } from '@/common/component/code-highlighter'
import { LiteralBox } from '@/common/component/LiteralBox'
import { useSiteViewmodel } from '@/context/site'
import { useJsonViewViewModel } from '../context'

export const LiteralPane: React.FC = () => {
  const site = useSiteViewmodel()
  const palette = useStateValue(site.palette$)
  const themeScheme: IPrismThemeScheme = getPrismTheme(palette)

  const viewmodel = useJsonViewViewModel()
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
    <LiteralBox content={content || ''}>
      <CodeHighlighter
        themeScheme={themeScheme}
        lang="json"
        code={content || ''}
        collapsed={false}
        showLineno={true}
      />
    </LiteralBox>
  )
}

LiteralPane.displayName = 'JsonViewLiteralPane'
