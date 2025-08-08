import React from 'react'
import { useFileResult } from '@/hook/useFileResult'
import type { IJsonFileData } from '@/util/fetch'
import { useExcalidrawViewState, useExcalidrawViewViewModel } from '../context'
import { ExcalidrawComposer } from './ExcalidrawComposer'

interface IProps {
  readonly filepathDirtyTick: number
}

export const ExcalidrawLayout: React.FC<IProps> = props => {
  const { filepathDirtyTick } = props
  const { workspace, filepath, error: contextError } = useExcalidrawViewState()
  const viewmodel = useExcalidrawViewViewModel()

  const { data, error: fileError } = useFileResult<IJsonFileData>(
    workspace,
    filepath,
    filepathDirtyTick,
  )
  const error = contextError || fileError

  React.useEffect(() => {
    if (data?.content) {
      viewmodel.content$.setState(() => data.content)
    }
  }, [data?.content, viewmodel.content$])

  React.useEffect(() => {
    if (error) {
      viewmodel.error$.setState(() => String(error))
    } else {
      viewmodel.error$.setState(() => null)
    }
  }, [error, viewmodel.error$])

  return (
    <div className="w-full pt-8">
      {!!error && (
        <div className="relative mb-12 flex-none bg-gray-100 px-2 py-1.5 text-base text-red-500 dark:bg-gray-800 dark:text-red-400">
          <code>error: {String(error)}</code>
        </div>
      )}
      {!!data && (
        <div className="relative w-full">
          <ExcalidrawComposer />
        </div>
      )}
    </div>
  )
}

ExcalidrawLayout.displayName = 'ExcalidrawLayout'
