import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { useImageViewViewModel } from './context'
import { Main } from './layout/main'
import { Topbar } from './layout/topbar'

export const Composer: React.FC = () => {
  const viewmodel = useImageViewViewModel()
  const error = useStateValue(viewmodel.error$)

  if (error) {
    return (
      <div className="relative size-full flex items-center bg-gray-100 text-red-500 dark:bg-gray-800 dark:text-red-400">
        <code>error: {String(error)}</code>
      </div>
    )
  }

  return (
    <div className="border-box relative size-full">
      <div className="border-box fixed right-4 z-50 h-12">
        <Topbar />
      </div>
      <div className="border-box size-full pt-12">
        <Main />
      </div>
    </div>
  )
}

Composer.displayName = 'ImageViewComposer'
