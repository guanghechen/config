import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Root } from '@yozora/ast'
import type { IHeadingToc } from '@yozora/ast-util'
import React from 'react'
import { MarkdownContentProvider } from '@/component/markdown'
import { Composer } from './Composer'
import { MarkdownViewProvider, useMarkdownViewViewModel } from './context'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly mainScrollableContainer: HTMLDivElement | null
  readonly topbarVisible: boolean
}

export const MarkdownView: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, mainScrollableContainer, topbarVisible } = props

  if (!filepath) {
    return (
      <div className="w-full pt-8">
        <div className="text-center text-gray-500">No file specified</div>
      </div>
    )
  }

  return (
    <div className="w-full pt-8">
      <MarkdownViewProvider
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
      >
        <MarkdownContent
          filepath={filepath}
          mainScrollableContainer={mainScrollableContainer}
          topbarVisible={topbarVisible}
        />
      </MarkdownViewProvider>
    </div>
  )
}

MarkdownView.displayName = 'MarkdownView'

interface IMarkdownContentProps {
  readonly filepath: string
  readonly mainScrollableContainer: HTMLDivElement | null
  readonly topbarVisible: boolean
}

const MarkdownContent: React.FC<IMarkdownContentProps> = props => {
  const { filepath, mainScrollableContainer, topbarVisible } = props
  const viewmodel = useMarkdownViewViewModel()
  const data = useStateValue(viewmodel.data$)
  const error = useStateValue(viewmodel.error$)

  const ast: Root | undefined = data?.ast
  const toc: IHeadingToc | undefined = data?.toc
  const frontmatter: Record<string, unknown> | undefined = data?.frontmatter

  return (
    <React.Fragment>
      {!!error && (
        <div className="mb-12 flex-none bg-gray-100 px-2 py-1.5 text-base text-red-500 dark:bg-gray-800 dark:text-red-400">
          <code>error: {String(error)}</code>
        </div>
      )}
      {!!ast && (
        <MarkdownContentProvider ast={ast}>
          <div className="w-full">
            <Composer
              filepath={filepath}
              frontmatter={frontmatter}
              toc={toc}
              mainScrollableContainer={mainScrollableContainer}
              topbarVisible={topbarVisible}
            />
          </div>
        </MarkdownContentProvider>
      )}
    </React.Fragment>
  )
}
