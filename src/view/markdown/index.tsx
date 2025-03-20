import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Root } from '@yozora/ast'
import React from 'react'
import { ReactMarkdown } from '@/component/markdown'
import type { SiteTheme } from '@/context/site'
import { useSiteViewmodel } from '@/context/site'
import { useFileResult } from '@/hook/useFileResult'
import { Sidebar } from './sidebar'
import { Topbar } from './topbar'

export const MarkdownView: React.FC = () => {
  const siteViewModel = useSiteViewmodel()
  const theme: SiteTheme = useStateValue(siteViewModel.theme$)
  const workspace: string | null = useStateValue(siteViewModel.workspace$)
  const filepath = useStateValue(siteViewModel.filepath$)
  const tick: number = useStateValue(siteViewModel.filepathDirtyTick$)
  const { data, error } = useFileResult(workspace, filepath, tick)
  const ast: Root | undefined = data?.ast

  return (
    <div className="relative box-border flex h-screen w-screen overflow-auto bg-gray-50 font-['Maple_Mono_NF_CN','Roboto_Mono',monospace,sans-serif] text-gray-800 shadow-md transition-colors duration-300 ease-in-out dark:bg-gray-900 dark:text-gray-200 [&::-webkit-scrollbar-thumb]:rounded [&::-webkit-scrollbar-thumb]:bg-gray-300 [&::-webkit-scrollbar-thumb]:hover:bg-gray-400 dark:[&::-webkit-scrollbar-thumb]:bg-gray-600 dark:[&::-webkit-scrollbar-thumb]:hover:bg-gray-500 [&::-webkit-scrollbar-track]:bg-gray-50 dark:[&::-webkit-scrollbar-track]:bg-gray-900 [&::-webkit-scrollbar]:w-2">
      <div className="sticky top-0 h-screen w-64 flex-none border-r border-gray-200 bg-gray-50 shadow-sm dark:border-gray-700 dark:bg-gray-900">
        <Sidebar />
      </div>
      <div className="flex flex-1 flex-col">
        <div className="sticky top-0 z-10 h-8 border-b border-gray-200 bg-gray-50 dark:border-gray-700 dark:bg-gray-900">
          <Topbar />
        </div>
        <div className="min-h-[calc(100vh-2rem)]">
          <div className="flex justify-center py-4">
            {!!error && (
              <div className="flex-none bg-gray-100 px-2 py-1.5 text-base text-red-500 dark:bg-gray-800 dark:text-red-400">
                <code>error: {String(error)}</code>
              </div>
            )}
            {!!ast && (
              <div className="w-[800px]">
                <ReactMarkdown ast={ast} theme={theme} />
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
MarkdownView.displayName = 'MarkdownView'
