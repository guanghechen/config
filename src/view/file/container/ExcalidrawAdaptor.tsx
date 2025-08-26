import { useEventCallback } from '@guanghechen/react-hooks'
import React from 'react'
import { usePostFile } from '@/hook/api/file/save'
import { useFileResult } from '@/hook/useFileResult'
import type { ITextFileData } from '@/shared/types/api'
import { ExcalidrawView } from '@/view/filetype/excalidraw/View'
import { useFileViewmodel } from '../context'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly storageKeyScope: string
}

export const ExcalidrawAdaptor: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, storageKeyScope } = props
  const { save: saveFile } = usePostFile()
  const viewmodel = useFileViewmodel()
  const fileResult = useFileResult<ITextFileData>(workspace, filepath, filepathDirtyTick)

  // Transform data to new props format
  const content = fileResult.data?.content || fileResult.text || null
  const contentError = fileResult.error ? String(fileResult.error) : null

  // Create save callback for excalidraw
  const handleSaveFile = useEventCallback(async (content: string) => {
    if (filepath) {
      try {
        await saveFile({ workspace, filepath, content })
        viewmodel.markFilepathDirty()
      } catch (error) {
        console.error('Failed to save file:', error)
      }
    }
  })

  return (
    <ExcalidrawView
      content={content}
      contentError={contentError}
      onSaveFile={handleSaveFile}
      storageKeyScope={storageKeyScope}
    />
  )
}
