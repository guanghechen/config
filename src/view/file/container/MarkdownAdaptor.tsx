import React from 'react'
import { useFileResult } from '@/hook/useFileResult'
import type { IMarkdownFileData } from '@/shared/types/api'
import { MarkdownView } from '@/view/filetype/markdown/View'

interface IProps {
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly storageKeyScope: string
}

export const MarkdownAdaptor: React.FC<IProps> = ({
  filepath,
  filepathDirtyTick,
  storageKeyScope,
}) => {
  const fileResult = useFileResult<IMarkdownFileData>(filepath, filepathDirtyTick)

  // Pass the structured markdown data directly to the view
  const data = fileResult.data || null
  const dataError = fileResult.error ? String(fileResult.error) : null

  return <MarkdownView data={data} dataError={dataError} storageKeyScope={storageKeyScope} />
}
