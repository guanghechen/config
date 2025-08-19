import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Root } from '@yozora/ast'
import React from 'react'
import { MarkdownContentProvider } from '@/component/markdown'
import { useMarkdownViewViewModel } from './context'
import { Main } from './layout/main'
import { Topbar } from './layout/topbar'

interface IProps {
  readonly filepath: string
  readonly workspace: string | null
}

export const Composer: React.FC<IProps> = props => {
  const { filepath, workspace } = props
  const viewmodel = useMarkdownViewViewModel()
  const data = useStateValue(viewmodel.data$)
  const ast: Root | undefined = data?.ast

  return (
    <div className="f-vf-root" data-filetype="markdown">
      <Topbar filepath={filepath} workspace={workspace} />
      {!!ast && (
        <MarkdownContentProvider ast={ast}>
          <Main />
        </MarkdownContentProvider>
      )}
    </div>
  )
}

Composer.displayName = 'MarkdownViewComposer'
