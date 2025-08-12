import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { DockToRightIcon } from '@/component/icon/material'
import { Float } from './container/float'
import { Main } from './container/Main'
import { Sidebar } from './container/sidebar'
import { Topbar } from './container/Topbar'
import { useWorkspaceViewmodel } from './context'

export const Composer: React.FC = () => {
  const viewmodel = useWorkspaceViewmodel()
  const topbarVisible = useStateValue(viewmodel.topbarVisible$)
  const onToggleBothSidebarAndTopbar = viewmodel.toggleBothSidebarAndTopbar
  const topbarHeight = topbarVisible ? '3rem' : '0rem'

  return (
    <div className="relative box-border flex w-full bg-gray-50 font-['Maple_Mono_NF_CN','Roboto_Mono',monospace,sans-serif] text-gray-800 shadow-md transition-colors duration-300 ease-in-out dark:bg-gray-900 dark:text-gray-200 [&::-webkit-scrollbar-thumb]:rounded [&::-webkit-scrollbar-thumb]:bg-gray-300 [&::-webkit-scrollbar-thumb]:hover:bg-gray-400 dark:[&::-webkit-scrollbar-thumb]:bg-gray-600 dark:[&::-webkit-scrollbar-thumb]:hover:bg-gray-500 [&::-webkit-scrollbar-track]:bg-gray-50 dark:[&::-webkit-scrollbar-track]:bg-gray-900 [&::-webkit-scrollbar]:w-2">
      {!topbarVisible && (
        <button
          onClick={onToggleBothSidebarAndTopbar}
          className="fixed left-4 top-4 z-50 rounded-lg bg-white/80 p-2 text-gray-600 shadow-lg backdrop-blur-md transition-colors hover:bg-white/90 hover:text-gray-800 dark:bg-gray-800/80 dark:text-gray-400 dark:hover:bg-gray-700/90 dark:hover:text-gray-200"
          title="Show sidebar and topbar"
        >
          <DockToRightIcon />
        </button>
      )}
      {topbarVisible && (
        <div className="sticky top-0 z-30 box-border h-[3rem] w-0 flex-initial">
          <div className="box-border h-full w-screen border-b border-gray-200 bg-gray-50 dark:border-gray-700 dark:bg-gray-900">
            <Topbar viewmodel={viewmodel} />
          </div>
        </div>
      )}
      <div
        className="sticky z-30 box-border flex-shrink-0 flex-grow-0"
        style={{
          left: 0,
          top: topbarHeight,
          height: `calc(100vh - ${topbarHeight})`,
        }}
      >
        <Sidebar viewmodel={viewmodel} />
      </div>
      <div className="box-border min-h-screen w-0 flex-auto" style={{ paddingTop: topbarHeight }}>
        <div className="box-border flex w-full justify-center p-4">
          <Main viewmodel={viewmodel} />
        </div>
      </div>
      <div className="absolute right-0 top-0">
        <Float viewmodel={viewmodel} />
      </div>
    </div>
  )
}

Composer.displayName = 'WorkspaceComposer'
