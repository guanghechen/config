import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { usePdfViewViewModel } from './context'
import { Main } from './layout/main'
import { Topbar } from './layout/topbar'

export const Composer: React.FC = () => {
  const viewmodel = usePdfViewViewModel()
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
      <div className="box-border fixed right-4 z-50 h-12">
        <Topbar />
      </div>
      <div className="box-border size-full pt-12">
        <Main />
      </div>
    </div>
  )
}

Composer.displayName = 'PdfViewComposer'
