import React from 'react'
import { useFileResult } from '@/hook/useFileResult'
import type { IJsonFileData } from '@/util/fetch'
import { Composer } from './Composer'
import { ExcalidrawProvider } from './context/Provider'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly mainScrollableContainer: HTMLDivElement | null
}

const ExcalidrawView: React.FC<IProps> = props => {
  const { workspace, filepath, filepathDirtyTick, mainScrollableContainer } = props

  const { data, error } = useFileResult<IJsonFileData>(workspace, filepath, filepathDirtyTick)

  return (
    <div className="w-full pt-8">
      {!!error && (
        <div className="relative mb-12 flex-none bg-gray-100 px-2 py-1.5 text-base text-red-500 dark:bg-gray-800 dark:text-red-400">
          <code>error: {String(error)}</code>
        </div>
      )}
      {!!data && (
        <div className="relative w-full">
          <ExcalidrawProvider>
            <Composer
              workspace={workspace}
              filepath={filepath}
              filepathDirtyTick={filepathDirtyTick}
              mainScrollableContainer={mainScrollableContainer}
            />
          </ExcalidrawProvider>
        </div>
      )}
    </div>
  )
}

ExcalidrawView.displayName = 'ExcalidrawView'

export default React.memo(ExcalidrawView, () => true)

// Export components, hooks, types and utils for reuse
export { ExcalidrawProvider } from './context/Provider'
export { Composer as ExcalidrawComposer } from './Composer'
export { ExcalidrawLayout } from './container/layout'
export { useExcalidrawViewModel } from './context/hook'
export type { IExcalidrawData } from './context/types'
