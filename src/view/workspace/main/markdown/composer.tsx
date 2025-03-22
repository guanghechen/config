import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Root } from '@yozora/ast'
import React from 'react'
import { ReactMarkdown } from '@/component/markdown'
import type { SiteTheme } from '@/context/site'
import { useSiteViewmodel } from '@/context/site'
import type { MarkdownModeEnum } from './types'

interface IProps {
  readonly ast: Root
  readonly mode: MarkdownModeEnum
}

export const MarkdownComposer: React.FC<IProps> = props => {
  const { ast, mode } = props
  const siteVM = useSiteViewmodel()
  const theme: SiteTheme = useStateValue(siteVM.theme$)

  if (mode === 'ast') {
    return (
      <div className="overflow-auto p-4">
        <pre className="whitespace-pre-wrap break-words text-sm">
          <code>{JSON.stringify(ast, null, 2)}</code>
        </pre>
      </div>
    )
  }

  return <ReactMarkdown ast={ast} theme={theme} />
}

MarkdownComposer.displayName = 'MarkdownComposer'
