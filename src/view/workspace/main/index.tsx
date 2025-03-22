import React from 'react'
import { MarkdownContainer } from './markdown'

export const WorkspaceMain: React.FC = () => {
  return (
    <div className="flex justify-center py-4">
      <div className="box-border w-[800px]">
        <MarkdownContainer />
      </div>
    </div>
  )
}

WorkspaceMain.displayName = 'WorkspaceMain'
export default WorkspaceMain
