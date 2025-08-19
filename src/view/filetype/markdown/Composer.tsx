import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Root } from '@yozora/ast'
import React from 'react'
import { MarkdownContentProvider } from '@/component/markdown'
import { useMarkdownViewViewModel } from './context'
import { Main } from './layout/main'
import { ModeToggle } from './layout/mode'

export const Composer: React.FC = () => {
  const viewmodel = useMarkdownViewViewModel()
  const data = useStateValue(viewmodel.data$)
  const ast: Root | undefined = data?.ast

  return (
    <React.Fragment>
      {!!ast && (
        <MarkdownContentProvider ast={ast}>
          <Main />
        </MarkdownContentProvider>
      )}
      <ModeToggle />
    </React.Fragment>
  )
}

Composer.displayName = 'MarkdownViewComposer'
