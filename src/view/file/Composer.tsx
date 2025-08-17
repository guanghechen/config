import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useFileViewmodel } from './context'
import { Main } from './layout/main'
import { Topbar } from './layout/topbar'

export const Composer: React.FC = () => {
  const viewmodel = useFileViewmodel()
  const filepath = useStateValue(viewmodel.filepath$)
  const filepathDirtyTick: number = useStateValue(viewmodel.filepathDirtyTick$)

  return (
    <div className="relative min-h-screen w-full bg-gray-50 font-mono-maple text-gray-800 transition-colors duration-300 ease-in-out dark:bg-gray-900 dark:text-gray-200">
      <Topbar filepath={filepath} />
      <div className="flex min-h-screen justify-center p-4">
        <Main filepath={filepath} filepathDirtyTick={filepathDirtyTick} />
      </div>
    </div>
  )
}

Composer.displayName = 'FileComposer'
