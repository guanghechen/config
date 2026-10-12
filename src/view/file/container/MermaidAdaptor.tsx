import React from 'react'
import { useFileResult } from '@/hook/useFileResult'
import type { ITextFileData } from '@/shared/types/api'
import { MermaidView } from '@/view/filetype/mermaid/View'

interface IProps {
  readonly filepath: string
  readonly filepathDirtyTick: number
}

export const MermaidAdaptor: React.FC<IProps> = ({ filepath, filepathDirtyTick }) => {
  const fileResult = useFileResult<ITextFileData>(filepath, filepathDirtyTick)

  return (
    <MermaidView
      content={fileResult.data?.content ?? null}
      contentError={fileResult.error ? String(fileResult.error) : null}
      loading={fileResult.loading ?? false}
    />
  )
}
MermaidAdaptor.displayName = 'MermaidAdaptor'
