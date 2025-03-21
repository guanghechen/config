import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Root } from '@yozora/ast'
import React from 'react'
import { ReactMarkdown } from '@/component/markdown'
import type { SiteTheme } from '@/context/site'
import { useSiteViewmodel } from '@/context/site'
import { useFileResult } from '@/hook/useFileResult'
import { useWorkspaceViewmodel } from '../context'

export const MarkdownContainer: React.FC = () => {
  const siteVM = useSiteViewmodel()
  const workspaceVM = useWorkspaceViewmodel()
  const theme: SiteTheme = useStateValue(siteVM.theme$)
  const workspace: string | null = useStateValue(workspaceVM.workspace$)
  const filepath = useStateValue(workspaceVM.filepath$)
  const tick: number = useStateValue(workspaceVM.filepathDirtyTick$)
  const { data, error } = useFileResult(workspace, filepath, tick)
  const ast: Root | undefined = data?.ast

  return (
    <div className="box-border w-[800px]">
      {!!error && (
        <div className="mb-12 flex-none bg-gray-100 px-2 py-1.5 text-base text-red-500 dark:bg-gray-800 dark:text-red-400">
          <code>error: {String(error)}</code>
        </div>
      )}
      {ast && <ReactMarkdown ast={ast} theme={theme} />}
    </div>
  )
}

MarkdownContainer.displayName = 'MarkdownContainer'
