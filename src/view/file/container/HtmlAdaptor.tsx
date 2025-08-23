import React from 'react'
import { useFileResult } from '@/hook/useFileResult'
import type { IHtmlFileData } from '@/shared/types/api'
import { HtmlView } from '@/view/filetype/html/View'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
}

export const HtmlAdaptor: React.FC<IProps> = ({ workspace, filepath, filepathDirtyTick }) => {
  const fileResult = useFileResult<IHtmlFileData>(workspace, filepath, filepathDirtyTick)
  const content = fileResult.data?.content || fileResult.text || null
  const contentError = fileResult.error ? String(fileResult.error) : null
  return <HtmlView content={content} contentError={contentError} />
}
