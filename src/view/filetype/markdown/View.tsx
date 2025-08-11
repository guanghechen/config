import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Root } from '@yozora/ast'
import type { IHeadingToc } from '@yozora/ast-util'
import React from 'react'
import { MarkdownProvider } from '@/component/markdown'
import type { SiteTheme } from '@/context/site'
import { useSiteViewmodel } from '@/context/site'
import { useFileResult } from '@/hook/useFileResult'
import type { IMarkdownFileData } from '@/util/fetch'
import { Composer } from './Composer'
import { MarkdownViewProvider } from './context'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly mainScrollableContainer: HTMLDivElement | null
  readonly topbarVisible: boolean
}

export const MarkdownView: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, mainScrollableContainer, topbarVisible } = props
  const siteVM = useSiteViewmodel()
  const theme: SiteTheme = useStateValue(siteVM.theme$)

  const { data, error } = useFileResult<IMarkdownFileData>(workspace, filepath, filepathDirtyTick)
  const ast: Root | undefined = data?.ast
  const toc: IHeadingToc | undefined = data?.toc
  const frontmatter: Record<string, unknown> | undefined = data?.frontmatter

  return (
    <div className="w-full pt-8">
      {!!error && (
        <div className="mb-12 flex-none bg-gray-100 px-2 py-1.5 text-base text-red-500 dark:bg-gray-800 dark:text-red-400">
          <code>error: {String(error)}</code>
        </div>
      )}
      {!!ast && (
        <MarkdownProvider ast={ast} theme={theme}>
          <MarkdownViewProvider>
            <div className="w-full">
              <Composer
                filepath={filepath}
                frontmatter={frontmatter}
                toc={toc}
                mainScrollableContainer={mainScrollableContainer}
                topbarVisible={topbarVisible}
              />
            </div>
          </MarkdownViewProvider>
        </MarkdownProvider>
      )}
    </div>
  )
}

MarkdownView.displayName = 'MarkdownView'
