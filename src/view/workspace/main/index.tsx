import React from 'react'
import { MarkdownContainer } from './markdown'

export const WorkspaceMain: React.FC = () => {
  return (
    <div className="box-border flex h-full justify-center">
      <div className="box-border h-full w-full p-8">
        <MarkdownContainer />
      </div>
    </div>
  )
}

WorkspaceMain.displayName = 'WorkspaceMain'
export default WorkspaceMain
