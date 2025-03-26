import React from 'react'

export const ChevronDownIcon: React.FC<{ className?: string }> = () => {
  return <span className="mr-2 text-gray-500"> </span>
}

export const ChevronRightIcon: React.FC<{ className?: string }> = () => {
  return <span className="mr-2 text-gray-500"> </span>
}

export const FolderIcon: React.FC<{ className?: string }> = () => {
  return <span className="mr-2 text-blue-500"> </span>
}

export const FolderOpenIcon: React.FC<{ className?: string }> = () => {
  return <span className="mr-2 text-blue-500"> </span>
}

export const FileTypeIcon: React.FC<{ extname: string }> = props => {
  const { extname } = props

  switch (extname) {
    case '.md':
      return <span className="mx-1 text-gray-700">󰍔 </span>
    case '.json':
      return <span className="mx-1 text-yellow-700">󰘦 </span>
    case '.pdf':
      return <span className="mx-1 text-yellow-700"> </span>
    case '.png':
    case '.jpg':
    case '.jpeg':
      return <span className="mx-1 text-blue-700">󰉏 </span>
    default:
      return <span className="mx-1 text-pink-700">󰈚 </span>
  }
}
