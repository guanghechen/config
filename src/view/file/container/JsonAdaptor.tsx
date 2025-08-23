import React from 'react'
import { useFileResult } from '@/hook/useFileResult'
import type { IJsonFileData } from '@/shared/types/api'
import { JsonView } from '@/view/filetype/json/View'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
}

export const JsonAdaptor: React.FC<IProps> = ({ workspace, filepath, filepathDirtyTick }) => {
  const fileResult = useFileResult<IJsonFileData>(workspace, filepath, filepathDirtyTick)

  // Transform data to new props format
  const content = fileResult.data?.content || fileResult.text || null
  const contentError = fileResult.error ? String(fileResult.error) : null

  return <JsonView content={content} contentError={contentError} />
}
