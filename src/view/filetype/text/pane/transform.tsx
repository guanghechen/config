import cn from 'clsx'
import React from 'react'
import { PRESET_CLASSES } from '@/shared/constant'
import { TransformMode } from '../container/TransformMode'

interface IProps {
  readonly columns: number
}

export const TransformPane: React.FC<IProps> = props => {
  const { columns } = props

  return (
    <div
      className={cn('box-border p-8 overflow-auto h-full', PRESET_CLASSES.scrollbar, {
        'p-2': columns > 1,
      })}
    >
      <TransformMode />
    </div>
  )
}

TransformPane.displayName = 'TextTransformPane'
