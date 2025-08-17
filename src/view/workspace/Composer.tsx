import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { FileSearch } from './container/FileSearch'
import { Main } from './container/Main'
import { Sidebar } from './container/sidebar'
import { Topbar } from './container/Topbar'
import { useWorkspaceViewmodel } from './context'

export const Composer: React.FC = () => {
  const viewmodel = useWorkspaceViewmodel()
  const visible: boolean = useStateValue(viewmodel.sidebarVisible$)
  const width: number = useStateValue(viewmodel.sidebarWidth$) // don't subscribe the width change since we adjust it in resizer callback

  return (
    <div className="relative box-border flex font-mono-maple text-gray-800 shadow-md transition-colors duration-300 ease-in-out dark:text-gray-200 [&::-webkit-scrollbar-thumb]:rounded [&::-webkit-scrollbar-thumb]:bg-gray-300 [&::-webkit-scrollbar-thumb]:hover:bg-gray-400 dark:[&::-webkit-scrollbar-thumb]:bg-gray-600 dark:[&::-webkit-scrollbar-thumb]:hover:bg-gray-500 [&::-webkit-scrollbar-track]:bg-gray-50 dark:[&::-webkit-scrollbar-track]:bg-gray-900 [&::-webkit-scrollbar]:w-2">
      <div
        className="sticky z-30 left-0 w-0 top-0 box-border flex-shrink-0 flex-grow-0"
        style={{ width: visible ? width : 0 }}
      >
        <div className="box-border h-12">
          <Topbar />
        </div>
        <div className="box-border">
          <Sidebar />
        </div>
      </div>
      <div className="box-border min-h-screen w-0 flex-auto">
        <div className="box-border flex w-full min-h-screen justify-center p-4">
          <Main />
        </div>
      </div>
      <div className="absolute right-0 top-0">
        <FileSearch />
      </div>
    </div>
  )
}

Composer.displayName = 'WorkspaceComposer'
