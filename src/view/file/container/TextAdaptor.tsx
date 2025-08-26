import React from 'react'
import { useFileResult } from '@/hook/useFileResult'
import type { ITextFileData } from '@/shared/types/api'
import { TextView } from '@/view/filetype/text/View'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly storageKeyScope: string
}

export const TextAdaptor: React.FC<IProps> = ({
  workspace,
  filepath,
  filepathDirtyTick,
  storageKeyScope,
}) => {
  const fileResult = useFileResult<ITextFileData>(workspace, filepath, filepathDirtyTick)

  // Transform data to new props format
  const content = fileResult.data?.content || fileResult.text || null
  const contentError = fileResult.error ? String(fileResult.error) : null

  return (
    <TextView content={content} contentError={contentError} storageKeyScope={storageKeyScope} />
  )
}
