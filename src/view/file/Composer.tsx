import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { Main } from './container/Main'
import { useFileViewmodel } from './context'

export const Composer: React.FC = () => {
  const viewmodel = useFileViewmodel()
  const filepath = useStateValue(viewmodel.filepath$)
  const filepathDirtyTick: number = useStateValue(viewmodel.filepathDirtyTick$)

  return (
    <div className="min-h-screen w-full bg-gray-50 font-['Maple_Mono_NF_CN','Roboto_Mono',monospace,sans-serif] text-gray-800 transition-colors duration-300 ease-in-out dark:bg-gray-900 dark:text-gray-200">
      <div className="flex w-full justify-center p-4">
        <Main filepath={filepath} filepathDirtyTick={filepathDirtyTick} />
      </div>
    </div>
  )
}

Composer.displayName = 'FileComposer'
