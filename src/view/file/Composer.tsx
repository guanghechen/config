import { useStateValue } from '@guanghechen/react-viewmodel'
import React from 'react'
import { Main } from './container/Main'
import { useFileViewmodel } from './context'

export const Composer: React.FC = () => {
  const viewmodel = useFileViewmodel()
  const filepath = useStateValue(viewmodel.filepath$)
  const filepathDirtyTick: number = useStateValue(viewmodel.filepathDirtyTick$)

  return (
    <div className="relative min-h-screen w-full bg-gray-50 font-['Maple_Mono_NF_CN','Roboto_Mono',monospace,sans-serif] text-gray-800 transition-colors duration-300 ease-in-out dark:bg-gray-900 dark:text-gray-200">
      {filepath && (
        <div className="absolute left-4 top-4 z-10 flex items-center gap-2">
          <span className="pointer-none text-sm text-gray-600 dark:text-gray-400 select-none">
            {filepath}
          </span>
          <a
            title="Open as raw"
            href={`/api/file/raw?filepath=${encodeURIComponent(filepath)}`}
            target="_blank"
            className="inline-flex cursor-pointer items-center text-blue-600 hover:text-blue-800 dark:text-blue-400 dark:hover:text-blue-300 transition-colors"
            rel="noreferrer"
          >
            <svg
              width="14"
              height="14"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6" />
              <polyline points="15,3 21,3 21,9" />
              <line x1="10" y1="14" x2="21" y2="3" />
            </svg>
          </a>
        </div>
      )}
      <div className="flex w-full justify-center p-4">
        <Main filepath={filepath} filepathDirtyTick={filepathDirtyTick} />
      </div>
    </div>
  )
}

Composer.displayName = 'FileComposer'
