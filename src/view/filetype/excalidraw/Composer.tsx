import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useExcalidrawViewViewModel } from './context'
import { Main } from './layout/main'

export const Composer: React.FC = () => {
  const viewmodel = useExcalidrawViewViewModel()
  const error = useStateValue(viewmodel.error$)

  if (error) {
    return (
      <div className="relative size-full flex items-center bg-gray-100 text-red-500 dark:bg-gray-800 dark:text-red-400">
        <code>error: {String(error)}</code>
      </div>
    )
  }

  return (
    <div className="box-border relative size-full">
      <Main />
    </div>
  )
}

Composer.displayName = 'ExcalidrawViewComposer'
