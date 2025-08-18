import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { ModeEnum, useTextViewViewModel } from './context'
import { Main } from './layout/main'
import { Mode } from './layout/mode'

export const Composer: React.FC = () => {
  const viewmodel = useTextViewViewModel()
  const mode = useStateValue(viewmodel.mode$)
  const error = useStateValue(viewmodel.error$)

  const showView: boolean = (mode & ModeEnum.VIEW) !== 0
  const showRaw: boolean = (mode & ModeEnum.RAW) !== 0
  const showTransform: boolean = (mode & ModeEnum.TRANSFORM) !== 0
  const columns: number = (showView ? 1 : 0) + (showRaw ? 1 : 0) + (showTransform ? 1 : 0)

  if (error) {
    return (
      <div className="relative size-full flex items-center bg-gray-100 text-red-500 dark:bg-gray-800 dark:text-red-400">
        <code>error: {String(error)}</code>
      </div>
    )
  }

  return (
    <div
      className={cn(
        'box-border relative pt-12',
        columns > 1 ? 'w-screen h-[calc(100vh-3rem)]' : 'size-full',
      )}
    >
      <div className="box-border fixed top-4 right-4 z-50">
        <Mode />
      </div>
      <div className="box-border size-full">
        <Main />
      </div>
    </div>
  )
}

Composer.displayName = 'TextViewComposer'
