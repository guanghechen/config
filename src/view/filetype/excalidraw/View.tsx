import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { Composer } from './Composer'
import { ExcalidrawViewProvider, useExcalidrawViewViewModel } from './context'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly mainScrollableContainer: HTMLDivElement | null
}

export const ExcalidrawView: React.FC<IProps> = props => {
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
      <ExcalidrawViewProvider
        workspace={workspace}
        filepath={filepath}
        filepathDirtyTick={filepathDirtyTick}
      >
        <ExcalidrawContent
          workspace={workspace}
          filepath={filepath}
          filepathDirtyTick={filepathDirtyTick}
          mainScrollableContainer={mainScrollableContainer}
        />
      </ExcalidrawViewProvider>
    </div>
  )
}

ExcalidrawView.displayName = 'ExcalidrawView'

interface IExcalidrawContentProps {
  readonly workspace: string | null
  readonly filepath: string
  readonly filepathDirtyTick: number
  readonly mainScrollableContainer: HTMLDivElement | null
}

const ExcalidrawContent: React.FC<IExcalidrawContentProps> = props => {
  const { workspace, filepath, filepathDirtyTick, mainScrollableContainer } = props
  const viewmodel = useExcalidrawViewViewModel()
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
          <Composer
            workspace={workspace}
            filepath={filepath}
            filepathDirtyTick={filepathDirtyTick}
            mainScrollableContainer={mainScrollableContainer}
          />
        </div>
      )}
    </React.Fragment>
  )
}
