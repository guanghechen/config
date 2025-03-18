import cn from 'clsx'
import copy from 'copy-to-clipboard'
import React from 'react'
import { CheckIcon, CopyIcon } from '@/component/icon/material'

export enum CopyStatus {
  PENDING = 0,
  COPYING = 1,
  COPIED = 2,
  FAILED = 3,
}

export interface ICopyButtonProps {
  delay?: number
  className?: string
  calcContentForCopy: () => string
}

export const CopyButton: React.FC<ICopyButtonProps> = props => {
  const { className, delay = 1500, calcContentForCopy } = props
  const [status, setStatus] = React.useState<CopyStatus>(CopyStatus.PENDING)
  const disabled: boolean = status !== CopyStatus.PENDING

  const onCopy = (e: React.MouseEvent): void => {
    e.stopPropagation()
    if (status === CopyStatus.PENDING) {
      setStatus(CopyStatus.COPYING)
      try {
        const contentForCopy: string = calcContentForCopy()
        copy(contentForCopy)
        setStatus(CopyStatus.COPIED)
      } catch {
        setStatus(CopyStatus.FAILED)
      }
    }
  }

  React.useEffect((): (() => void) | undefined => {
    if (status === CopyStatus.COPIED || status === CopyStatus.FAILED) {
      const timer = setTimeout(() => setStatus(CopyStatus.PENDING), delay)
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
        status === CopyStatus.COPIED &&
          'text-green-600 dark:text-green-400 bg-green-50 dark:bg-green-500/20 border-green-500 dark:border-green-400/50',
        status === CopyStatus.FAILED && 'text-red-600 dark:text-red-400',
        className,
      )}
      disabled={disabled}
      onClick={onCopy}
      title={status === CopyStatus.COPIED ? 'Copied!' : 'Copy to clipboard'}
    >
      <span className="flex items-center justify-center">
        {status === CopyStatus.COPIED ? (
          <CheckIcon className="h-4 w-4" />
        ) : (
          <CopyIcon className="h-4 w-4" />
        )}
      </span>
      <span
        className={cn(
          'transition-opacity duration-200',
          status === CopyStatus.COPIED || status === CopyStatus.FAILED
            ? 'font-semibold opacity-100'
            : 'opacity-0',
        )}
      >
        {status === CopyStatus.COPIED ? 'Copied!' : status === CopyStatus.FAILED ? 'Failed' : ''}
      </span>
    </button>
  )
}
