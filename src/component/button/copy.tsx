import cn from 'clsx'
import copy from 'copy-to-clipboard'
import React from 'react'
import { CheckIcon, CopyIcon } from '../icon/material'

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

interface IState {
  readonly status: CopyStatusEnum
}

export class CopyButton extends React.Component<IProps, IState> {
  public static displayName = 'CopyButton'

  protected timer: NodeJS.Timeout | null = null

  constructor(props: IProps) {
    super(props)
    this.state = {
      status: CopyStatusEnum.PENDING,
    }
  }

  public override render(): React.ReactNode {
    const { className, nopadding = false } = this.props
    const { status } = this.state
    const disabled: boolean = status !== CopyStatusEnum.PENDING

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
          onClick={this.onCopy}
          title={this.getTooltipText()}
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

  public override componentDidMount(): void {
    this.setupTimer()
  }

  public override componentDidUpdate(prevProps: IProps, prevState: IState): void {
    if (prevState.status !== this.state.status) {
      this.setupTimer()
    }
    if (prevProps.delay !== this.props.delay) {
      this.setupTimer()
    }
  }

  public override componentWillUnmount(): void {
    this.clearTimer()
  }

  protected setupTimer = (): void => {
    this.clearTimer()
    const { status } = this.state
    const { delay = 1500 } = this.props

    if (status === CopyStatusEnum.COPIED || status === CopyStatusEnum.FAILED) {
      this.timer = setTimeout(() => {
        this.setState({ status: CopyStatusEnum.PENDING })
      }, delay)
    }
  }

  protected clearTimer = (): void => {
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }
  }

  protected onCopy = (e: React.MouseEvent): void => {
    e.stopPropagation()
    const { status } = this.state
    const { calcContentForCopy } = this.props

    if (status === CopyStatusEnum.PENDING) {
      this.setState({ status: CopyStatusEnum.COPYING })
      try {
        const contentForCopy: string = calcContentForCopy()
        copy(contentForCopy)
        this.setState({ status: CopyStatusEnum.COPIED })
      } catch {
        this.setState({ status: CopyStatusEnum.FAILED })
      }
    }
  }

  protected getTooltipText = (): string => {
    const { status } = this.state
    switch (status) {
      case CopyStatusEnum.COPIED:
        return 'Copied!'
      case CopyStatusEnum.FAILED:
        return 'Failed to copy'
      default:
        return 'Copy to clipboard'
    }
  }
}
