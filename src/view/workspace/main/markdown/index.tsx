import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Root } from '@yozora/ast'
import React from 'react'
import { useFileResult } from '@/hook/useFileResult'
import { useWorkspaceViewmodel } from '../../context'
import { MarkdownComposer } from './composer'
import { MarkdownModeToggle } from './mode'
import { MarkdownModeEnum } from './types'

export const MarkdownContainer: React.FC = () => {
  const workspaceVM = useWorkspaceViewmodel()
  const workspace: string | null = useStateValue(workspaceVM.workspace$)
  const filepath = useStateValue(workspaceVM.filepath$)
  const tick: number = useStateValue(workspaceVM.filepathDirtyTick$)
  const { data, error } = useFileResult(workspace, filepath, tick)
  const ast: Root | undefined = data?.ast

  const [mode, setMode] = React.useState<MarkdownModeEnum>(MarkdownModeEnum.PREVIEW)
  const onModeToggle = React.useCallback(() => {
    setMode(m => (m === MarkdownModeEnum.PREVIEW ? MarkdownModeEnum.AST : MarkdownModeEnum.PREVIEW))
  }, [])

  return (
    <div className="relative">
      <div className="relative mb-12 flex-none bg-gray-100 px-2 py-1.5 text-base text-red-500 dark:bg-gray-800 dark:text-red-400">
        <code>error: {String(error)}</code>
      </div>
      {!!ast && (
        <div className="relative">
          <MarkdownModeToggle mode={mode} onToggle={onModeToggle} />
          <MarkdownComposer ast={ast} mode={mode} />
        </div>
      )}
    </div>
  )
}

MarkdownContainer.displayName = 'MarkdownContainer'
