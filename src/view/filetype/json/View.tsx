import React from 'react'
import { useFileResult } from '@/hook/useFileResult'
import type { IJsonFileData } from '@/util/fetch'
import { Composer } from './Composer'
import { ModeToggle } from './container/ModeToggle'
import { JsonProvider } from './context/Provider'

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
  readonly filepathDirtyTick: number
  readonly mainScrollableContainer: HTMLDivElement | null
}

const JsonView: React.FC<IProps> = props => {
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
          <JsonProvider>
            <ModeToggle />
            <Composer mainScrollableContainer={mainScrollableContainer} />
          </JsonProvider>
        </div>
      )}
    </div>
  )
}

JsonView.displayName = 'JsonView'
