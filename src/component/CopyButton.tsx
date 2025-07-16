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
  readonly nopadding?: boolean
  readonly calcContentForCopy: () => string
}

export const CopyButton: React.FC<IProps> = props => {
  const { className, delay = 1500, nopadding = false, calcContentForCopy } = props
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

  const getTooltipText = (): string => {
    switch (status) {
      case CopyStatusEnum.COPIED:
        return 'Copied!'
      case CopyStatusEnum.FAILED:
        return 'Failed to copy'
      default:
        return 'Copy to clipboard'
    }
  }

  return (
    <div className="relative inline-block">
      <button
        className={cn(
          'flex items-center justify-center rounded-md text-xs font-medium',
          'bg-transparent border border-transparent transition-all duration-200',
          'text-gray-500 dark:text-gray-400 cursor-pointer',
          'hover:bg-gray-100 dark:hover:bg-white/10',
          'focus:outline-hidden focus:ring-2 focus:ring-blue-300/50',
          'disabled:opacity-50 disabled:cursor-default',
          status === CopyStatusEnum.COPIED &&
            'text-green-600 dark:text-green-400 bg-green-50 dark:bg-green-500/20 border-green-500 dark:border-green-400/50',
          status === CopyStatusEnum.FAILED && 'text-red-600 dark:text-red-400',
          nopadding ? 'p-1' : 'py-1.5 px-2.5',
          className,
        )}
        disabled={disabled}
        onClick={onCopy}
        title={getTooltipText()}
      >
        <span className="flex items-center justify-center">
          {status === CopyStatusEnum.COPIED ? (
            <CheckIcon className="h-4 w-4" />
          ) : (
            <CopyIcon className="h-4 w-4" />
          )}
        </span>
      </button>

      {/* Tooltip */}
      {(status === CopyStatusEnum.COPIED || status === CopyStatusEnum.FAILED) && (
        <div
          className={cn(
            'absolute top-full left-1/2 transform -translate-x-1/2 mt-1 z-50',
            'px-2 py-1 text-xs font-medium rounded-md shadow-lg',
            'transition-opacity duration-200',
            'pointer-events-none',
            status === CopyStatusEnum.COPIED
              ? 'bg-green-600 text-white dark:bg-green-500'
              : 'bg-red-600 text-white dark:bg-red-500',
          )}
        >
          {status === CopyStatusEnum.COPIED ? 'Copied!' : 'Failed'}
          {/* Arrow pointing up */}
          <div
            className={cn(
              'absolute bottom-full left-1/2 transform -translate-x-1/2',
              'border-l-4 border-r-4 border-b-4 border-transparent',
              status === CopyStatusEnum.COPIED
                ? 'border-b-green-600 dark:border-b-green-500'
                : 'border-b-red-600 dark:border-b-red-500',
            )}
          />
        </div>
      )}
    </div>
  )
}
