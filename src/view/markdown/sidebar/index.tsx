import React from 'react'
import { FileTree } from './FileTree'
import { Workspace } from './Workspace'

export const Sidebar: React.FC = () => {
  return (
    <div className="h-full overflow-auto text-sm">
      <Workspace />
      <FileTree />
    </div>
  )
}
