import React from 'react'
import { useFileResult } from '@/hook/useFileResult'
import type { ISvgFileData } from '@/shared/types/api'
import { SvgView } from '@/view/filetype/svg/View'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly storageKeyScope: string
}

export const SvgAdaptor: React.FC<IProps> = ({
  workspace,
  filepath,
  filepathDirtyTick,
  storageKeyScope,
}) => {
  const fileResult = useFileResult<ISvgFileData>(workspace, filepath, filepathDirtyTick)

  // Transform data to new props format
  const content = fileResult.data?.content || fileResult.text || null
  const contentError = fileResult.error ? String(fileResult.error) : null

  return <SvgView content={content} contentError={contentError} storageKeyScope={storageKeyScope} />
}
