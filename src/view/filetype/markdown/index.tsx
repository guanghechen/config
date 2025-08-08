import React from 'react'
import { useFileResult } from '@/hook/useFileResult'
import type { IMarkdownFileData } from '@/util/fetch'
import { Composer } from './Composer'
import { MarkdownProvider } from './context/Provider'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly mainScrollableContainer: HTMLDivElement | null
}

const MarkdownView: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, mainScrollableContainer } = props

  const { data, error } = useFileResult<IMarkdownFileData>(workspace, filepath, filepathDirtyTick)

  return (
    <div className="w-full pt-8">
      {!!error && (
        <div className="relative mb-12 flex-none bg-gray-100 px-2 py-1.5 text-base text-red-500 dark:bg-gray-800 dark:text-red-400">
          <code>error: {String(error)}</code>
        </div>
      )}
      {!!data && (
        <div className="relative w-full">
          <MarkdownProvider>
            <Composer
              filepath={filepath}
              frontmatter={data.frontmatter}
              toc={data.toc}
              mainScrollableContainer={mainScrollableContainer}
            />
          </MarkdownProvider>
        </div>
      )}
    </div>
  )
}

MarkdownView.displayName = 'MarkdownView'

export default MarkdownView

export { Composer as MarkdownComposer } from './Composer'
export { useMarkdownContext, useMarkdownActions, useMarkdownState } from './context/hook'
export { ModeToggle as MarkdownModeToggle } from './container/ModeToggle'
