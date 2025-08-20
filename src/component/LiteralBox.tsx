import cn from 'clsx'
import React from 'react'
import { CopyButton } from './button/copy'

interface IProps {
  readonly children: React.ReactNode
  readonly content: string
  readonly className?: string
}

export const LiteralBox: React.FC<IProps> = ({ children, content, className }) => {
  const calcContentForCopy = React.useCallback((): string => {
    return content
  }, [content])

  return (
    <div className={cn('box-border size-full whitespace-nowrap relative', className)}>
      <div className="absolute top-2 right-2 z-10">
        <CopyButton calcContentForCopy={calcContentForCopy} />
      </div>
      {children}
    </div>
  )
}

LiteralBox.displayName = 'LiteralBox'
