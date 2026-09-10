import React from 'react'
import { useFileResult } from '@/hook/useFileResult'
import type { IJsonFileData } from '@/shared/types/api'
import { JsonView } from '@/view/filetype/json/View'

interface IProps {
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly storageKeyScope: string
}

export const JsonAdaptor: React.FC<IProps> = ({ filepath, filepathDirtyTick, storageKeyScope }) => {
  const fileResult = useFileResult<IJsonFileData>(filepath, filepathDirtyTick)

  // Transform data to new props format
  const content = fileResult.data?.content || fileResult.text || null
  const contentError = fileResult.error ? String(fileResult.error) : null

  return (
    <JsonView content={content} contentError={contentError} storageKeyScope={storageKeyScope} />
  )
}
