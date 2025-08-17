import cn from 'clsx'
import React from 'react'
import { PRESET_CLASSES } from '@/constant/classes'
import { TransformMode } from '../container/TransformMode'

interface IProps {
  readonly columns: number
}

export const TransformPane: React.FC<IProps> = props => {
  const { columns } = props

  return (
    <div
      className={cn('h-full w-[48rem] max-w-[100rem] flex-auto', PRESET_CLASSES.scrollbar, {
        'p-2 overflow-auto': columns > 1,
        'overflow-auto': columns === 1,
      })}
    >
      <TransformMode />
    </div>
  )
}

TransformPane.displayName = 'TextTransformPane'
