import { useStateValue } from '@guanghechen/react-viewmodel'
import type { IHeadingToc } from '@yozora/ast-util'
import React from 'react'
import { MarkdownToc } from '@/component/markdown'
import { useMarkdownViewViewModel } from '../context'

export const TocPane: React.FC = () => {
  const viewmodel = useMarkdownViewViewModel()
  const data = useStateValue(viewmodel.data$)
  const tocActivatedIdentifier = useStateValue(viewmodel.tocActivatedIdentifier$)

  const toc: IHeadingToc | undefined = data?.toc

  const setActivatedIdentifier = React.useCallback(
    (activatedIdentifier: string | null): void => {
      viewmodel.specifiedTocActivatedIdentifier$.next(activatedIdentifier)
    },
    [viewmodel],
  )

  return (
    <div className="flex-auto basis-0">
      <h3 className="text-lg p-0 m-0 mb-4 font-medium text-gray-800 dark:text-gray-100">
        Table of Contents
      </h3>
      <div>
        <MarkdownToc
          toc={toc}
          activatedIdentifier={tocActivatedIdentifier}
          setActivatedIdentifier={setActivatedIdentifier}
        />
      </div>
    </div>
  )
}

TocPane.displayName = 'MarkdownViewTocPane'
