import React from 'react'
import { useFileResult } from '@/hook/useFileResult'
import type { IPdfFileData } from '@/util/fetch'
import { Composer } from './Composer'
import { PdfViewProvider } from './context'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly mainScrollableContainer: HTMLDivElement | null
}

const PdfView: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, mainScrollableContainer } = props

  const { data, error } = useFileResult<IPdfFileData>(workspace, filepath, filepathDirtyTick)

  if (!filepath) {
    return (
      <div className="w-full pt-8">
        <div className="text-center text-gray-500">No file specified</div>
      </div>
    )
  }

  return (
    <div className="w-full pt-8">
      {!!error && (
        <div className="relative mb-12 flex-none bg-gray-100 px-2 py-1.5 text-base text-red-500 dark:bg-gray-800 dark:text-red-400">
          <code>error: {String(error)}</code>
        </div>
      )}
      {!!data && (
        <div className="relative w-full">
          <PdfViewProvider workspace={workspace} filepath={filepath}>
            <Composer mainScrollableContainer={mainScrollableContainer} />
          </PdfViewProvider>
        </div>
      )}
    </div>
  )
}

PdfView.displayName = 'PdfView'
