import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useFileViewmodel } from './context'
import { Main } from './layout/main'

export const Composer: React.FC = () => {
  const viewmodel = useFileViewmodel()
  const filepath = useStateValue(viewmodel.filepath$)
  const filepathDirtyTick: number = useStateValue(viewmodel.filepathDirtyTick$)

  return (
    <div className="f-vf-root transition-colors duration-300 ease-in-out bg-gray-50 text-gray-800 dark:bg-gray-900 dark:text-gray-200">
      <Main filepath={filepath} filepathDirtyTick={filepathDirtyTick} />
    </div>
  )
}

Composer.displayName = 'FileComposer'
