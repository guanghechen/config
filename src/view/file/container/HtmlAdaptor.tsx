import React from 'react'
import { useFileResult } from '@/hook/useFileResult'
import type { IHtmlFileData } from '@/shared/types/api'
import { HtmlView } from '@/view/filetype/html/View'

interface IProps {
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly storageKeyScope: string
}

export const HtmlAdaptor: React.FC<IProps> = ({ filepath, filepathDirtyTick, storageKeyScope }) => {
  const fileResult = useFileResult<IHtmlFileData>(filepath, filepathDirtyTick)
  const content = fileResult.data?.content || fileResult.text || null
  const contentError = fileResult.error ? String(fileResult.error) : null
  return (
    <HtmlView content={content} contentError={contentError} storageKeyScope={storageKeyScope} />
  )
}
