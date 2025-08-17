import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { Document, pdfjs } from 'react-pdf'
import { useScrollToTop } from '@/hook/useScrollToTop'
import { toSearch } from '@/shared/util'
import { Main } from './container/Main'
import { Topbar } from './container/Topbar'
import { usePdfViewViewModel } from './context'

pdfjs.GlobalWorkerOptions.workerSrc = new URL(
  'pdfjs-dist/build/pdf.worker.min.mjs',
  import.meta.url,
).toString()

const options = {
  cMapUrl: `https://unpkg.com/pdfjs-dist@${pdfjs.version}/cmaps/`,
}

interface IProps {
  readonly mainScrollableContainer: HTMLDivElement | null
}

export const Composer: React.FC<IProps> = props => {
  const { mainScrollableContainer } = props
  const viewmodel = usePdfViewViewModel()
  const workspace = useStateValue(viewmodel.workspace$)
  const filepath = useStateValue(viewmodel.filepath$)

  const { visible: visibleScrollToTop, scrollToTop } = useScrollToTop(mainScrollableContainer)

  const url = React.useMemo<string>(() => {
    const search = toSearch({ filepath, workspace })
    return `/api/file${search}`
  }, [filepath, workspace])

  return (
    <div className="w-full">
      <div className="w-full">
        <div className="h-[4rem] border-b border-gray-200 dark:border-gray-700">
          <Topbar />
        </div>
        <div className="flex justify-center p-4">
          <Document
            options={options}
            file={url}
            onLoadSuccess={({ numPages }) => viewmodel.pages$.next(numPages)}
            loading={
              <div className="flex h-64 w-full items-center justify-center">
                <div className="h-12 w-12 animate-spin rounded-full border-b-2 border-gray-900 dark:border-gray-100" />
              </div>
            }
            error={
              <div className="flex flex-col items-center justify-center rounded-lg border border-red-200 bg-red-50 p-6 text-center dark:border-red-800 dark:bg-red-900/20">
                <p className="mb-2 text-red-600 dark:text-red-400">Failed to load PDF document</p>
                <p className="text-sm text-gray-600 dark:text-gray-400">
                  Please check if the file exists and is a valid PDF
                </p>
              </div>
            }
          >
            <Main />
          </Document>
        </div>
      </div>
      <button
        onClick={scrollToTop}
        className={cn(
          'cursor-pointer fixed bottom-8 right-8 z-50 flex h-12 w-12 items-center justify-center rounded-full bg-blue-500 bg-opacity-60 text-white shadow-lg transition-all duration-300 hover:bg-blue-600 hover:bg-opacity-100',
          visibleScrollToTop
            ? 'translate-y-0 opacity-90'
            : 'pointer-events-none translate-y-16 opacity-0',
        )}
        title="Scroll to top"
        aria-label="Scroll to top"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          className="h-6 w-6"
          viewBox="0 0 24 24"
          fill="currentColor"
        >
          <path d="M7.41 15.41L12 10.83l4.59 4.58L18 14l-6-6-6 6z" />
        </svg>
      </button>
    </div>
  )
}

Composer.displayName = 'PdfComposer'
