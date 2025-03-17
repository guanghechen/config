import { css, cx } from '@emotion/css'
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

  const onCopy = (): void => {
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
      className={cx(
        classes.copyButton,
        className,
        status === CopyStatus.COPIED && classes.copied,
        status === CopyStatus.FAILED && classes.failed,
      )}
      disabled={disabled}
      onClick={onCopy}
      title={status === CopyStatus.COPIED ? 'Copied!' : 'Copy to clipboard'}
    >
      <span className={classes.iconWrapper}>
        {status === CopyStatus.COPIED ? (
          <CheckIcon className={classes.icon} />
        ) : (
          <CopyIcon className={classes.icon} />
        )}
      </span>
      <span
        className={cx(classes.statusText, {
          [classes.statusTextCopied]: status === CopyStatus.COPIED,
        })}
      >
        {status === CopyStatus.COPIED ? 'Copied!' : status === CopyStatus.FAILED ? 'Failed' : ''}
      </span>
    </button>
  )
}

const classes = {
  copyButton: css({
    display: 'flex',
    alignItems: 'center',
    gap: '6px',
    padding: '6px 10px',
    borderRadius: '6px',
    fontSize: '12px',
    fontWeight: 500,
    background: 'transparent',
    color: 'var(--color-text-secondary, #718096)',
    border: '1px solid transparent',
    transition: 'all 0.2s ease',
    cursor: 'pointer',
    '&:hover': {
      background: 'var(--color-bg-hover, rgba(0, 0, 0, 0.04))',
      color: 'var(--color-text-primary, #2d3748)',
      '@media (prefers-color-scheme: dark)': {
        background: 'rgba(255, 255, 255, 0.1)',
        color: 'var(--color-text-primary-dark, #f7fafc)',
      },
    },
    '&:focus': {
      outline: 'none',
      boxShadow: '0 0 0 2px rgba(66, 153, 225, 0.5)',
    },
    '&:disabled': {
      opacity: 0.5,
      cursor: 'default',
    },
    '@media (prefers-color-scheme: dark)': {
      color: 'var(--color-text-secondary-dark, #a0aec0)',
    },
  }),
  iconWrapper: css({
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
  }),
  icon: css({
    width: '16px',
    height: '16px',
  }),
  copied: css({
    color: 'var(--color-success, #38a169)',
    '@media (prefers-color-scheme: dark)': {
      color: 'var(--color-success-dark, #68d391)',
    },
  }),
  failed: css({
    color: 'var(--color-error, #e53e3e)',
    '@media (prefers-color-scheme: dark)': {
      color: 'var(--color-error-dark, #fc8181)',
    },
  }),
  statusText: css({
    opacity: 0,
    transition: 'opacity 0.2s ease',
  }),
  statusTextCopied: css({
    opacity: 1,
  }),
}
