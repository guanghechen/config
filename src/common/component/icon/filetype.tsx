import cn from 'clsx'
import React from 'react'

export const ChevronDownIcon: React.FC<{ className?: string }> = () => {
  return <span className="mr-2 text-gray-400 dark:text-gray-500"> </span>
}

export const ChevronRightIcon: React.FC<{ className?: string }> = () => {
  return <span className="mr-2 text-gray-400 dark:text-gray-500"> </span>
}

export const FolderIcon: React.FC<{ className?: string }> = () => {
  return <span className="mr-2 text-blue-300 dark:text-blue-400"> </span>
}

export const FolderOpenIcon: React.FC<{ className?: string }> = () => {
  return <span className="mr-2 text-blue-300 dark:text-blue-400"> </span>
}

export const FileTypeIcon: React.FC<{ extname: string; className?: string }> = props => {
  const { extname, className } = props

  switch (extname) {
    case '.md':
      return <span className={cn('mx-1 text-gray-700 dark:text-gray-300', className)}>󰍔 </span>
    case '.json':
      return <span className={cn('mx-1 text-yellow-700 dark:text-yellow-400', className)}>󰘦 </span>
    case '.eventstream':
      return <span className={cn('mx-1 text-green-700 dark:text-green-400', className)}>📡 </span>
    case '.pdf':
      return <span className={cn('mx-1 text-yellow-700 dark:text-yellow-400', className)}> </span>
    case '.png':
    case '.jpg':
    case '.jpeg':
      return <span className={cn('mx-1 text-blue-700 dark:text-blue-400', className)}>󰉏 </span>
    default:
      return <span className={cn('mx-1 text-pink-700 dark:text-pink-400', className)}>󰈚 </span>
  }
}
