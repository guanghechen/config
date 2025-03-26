import { useEventCallback } from '@guanghechen/react-hooks'
import cn from 'clsx'
import copy from 'copy-to-clipboard'
import React from 'react'
import { CheckIcon, CopyIcon } from './icon/material'

export enum CopyStatusEnum {
  PENDING = 0,
  COPYING = 1,
  COPIED = 2,
  FAILED = 3,
}

interface IProps {
  readonly delay?: number
  readonly className?: string
  readonly calcContentForCopy: () => string
}

export const CopyButton: React.FC<IProps> = props => {
  const { className, delay = 1500, calcContentForCopy } = props
  const [status, setStatus] = React.useState<CopyStatusEnum>(CopyStatusEnum.PENDING)
  const disabled: boolean = status !== CopyStatusEnum.PENDING

  const onCopy = useEventCallback((e: React.MouseEvent): void => {
    e.stopPropagation()
    if (status === CopyStatusEnum.PENDING) {
      setStatus(CopyStatusEnum.COPYING)
      try {
        const contentForCopy: string = calcContentForCopy()
        copy(contentForCopy)
        setStatus(CopyStatusEnum.COPIED)
      } catch {
        setStatus(CopyStatusEnum.FAILED)
      }
    }
  })

  React.useEffect((): (() => void) | undefined => {
    if (status === CopyStatusEnum.COPIED || status === CopyStatusEnum.FAILED) {
      const timer = setTimeout(() => setStatus(CopyStatusEnum.PENDING), delay)
      return () => {
        if (timer) {
          clearTimeout(timer)
        }
      }
    }

    return undefined
  }, [status, delay])

  return (
    <button
      className={cn(
        'flex items-center gap-1.5 py-1.5 px-2.5 rounded-md text-xs font-medium',
        'bg-transparent border border-transparent transition-all duration-200',
        'text-gray-500 dark:text-gray-400 cursor-pointer',
        'hover:bg-gray-100 dark:hover:bg-white/10',
        'focus:outline-none focus:ring-2 focus:ring-blue-300/50',
        'disabled:opacity-50 disabled:cursor-default',
        status === CopyStatusEnum.COPIED &&
          'text-green-600 dark:text-green-400 bg-green-50 dark:bg-green-500/20 border-green-500 dark:border-green-400/50',
        status === CopyStatusEnum.FAILED && 'text-red-600 dark:text-red-400',
        className,
      )}
      disabled={disabled}
      onClick={onCopy}
      title={status === CopyStatusEnum.COPIED ? 'Copied!' : 'Copy to clipboard'}
    >
      <span className="flex items-center justify-center">
        {status === CopyStatusEnum.COPIED ? (
          <CheckIcon className="h-4 w-4" />
        ) : (
          <CopyIcon className="h-4 w-4" />
        )}
      </span>
      <span
        className={cn(
          'transition-opacity duration-200',
          status === CopyStatusEnum.COPIED || status === CopyStatusEnum.FAILED
            ? 'font-semibold opacity-100'
            : 'opacity-0',
        )}
      >
        {status === CopyStatusEnum.COPIED
          ? 'Copied!'
          : status === CopyStatusEnum.FAILED
            ? 'Failed'
            : ''}
      </span>
    </button>
  )
}
