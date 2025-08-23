import React from 'react'
import { useFileResult } from '@/hook/useFileResult'
import type { IMarkdownFileData } from '@/shared/types/api'
import { MarkdownView } from '@/view/filetype/markdown/View'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
}

export const MarkdownAdaptor: React.FC<IProps> = ({ workspace, filepath, filepathDirtyTick }) => {
  const fileResult = useFileResult<IMarkdownFileData>(workspace, filepath, filepathDirtyTick)

  // Pass the structured markdown data directly to the view
  const data = fileResult.data || null
  const dataError = fileResult.error ? String(fileResult.error) : null

  return <MarkdownView data={data} dataError={dataError} />
}
