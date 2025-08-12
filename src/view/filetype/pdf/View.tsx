import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { Composer } from './Composer'
import { PdfViewProvider, usePdfViewViewModel } from './context'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly mainScrollableContainer: HTMLDivElement | null
}

export const PdfView: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, mainScrollableContainer } = props

  if (!filepath) {
    return (
      <div className="w-full pt-8">
        <div className="text-center text-gray-500">No file specified</div>
      </div>
    )
  }

  return (
    <div className="w-full pt-8">
      <PdfViewProvider
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
      >
        <PdfContent mainScrollableContainer={mainScrollableContainer} />
      </PdfViewProvider>
    </div>
  )
}

PdfView.displayName = 'PdfView'

const PdfContent: React.FC<{ mainScrollableContainer: HTMLDivElement | null }> = ({
  mainScrollableContainer,
}) => {
  const viewmodel = usePdfViewViewModel()
  const data = useStateValue(viewmodel.data$)
  const error = useStateValue(viewmodel.error$)

  return (
    <React.Fragment>
      {!!error && (
        <div className="relative mb-12 flex-none bg-gray-100 px-2 py-1.5 text-base text-red-500 dark:bg-gray-800 dark:text-red-400">
          <code>error: {String(error)}</code>
        </div>
      )}
      {!!data && (
        <div className="relative w-full">
          <Composer mainScrollableContainer={mainScrollableContainer} />
        </div>
      )}
    </React.Fragment>
  )
}
