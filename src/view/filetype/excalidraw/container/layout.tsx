import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useExcalidrawViewViewModel } from '../context'
import { ExcalidrawComposer } from './ExcalidrawComposer'

export const ExcalidrawLayout: React.FC = () => {
  const viewmodel = useExcalidrawViewViewModel()
  const data = useStateValue(viewmodel.data$)
  const error = useStateValue(viewmodel.error$)

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
