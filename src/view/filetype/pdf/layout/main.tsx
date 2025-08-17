import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { Document, Page, pdfjs } from 'react-pdf'
import { toSearch } from '@/shared/util'
import { usePdfViewViewModel } from '../context'

pdfjs.GlobalWorkerOptions.workerSrc = new URL(
  'pdfjs-dist/build/pdf.worker.min.mjs',
  import.meta.url,
).toString()

const options = {
  cMapUrl: `https://unpkg.com/pdfjs-dist@${pdfjs.version}/cmaps/`,
}

export const Main: React.FC = () => {
  const viewmodel = usePdfViewViewModel()
  const multiview = useStateValue(viewmodel.multiview$)
  const workspace = useStateValue(viewmodel.workspace$)
  const filepath = useStateValue(viewmodel.filepath$)
  const pages = useStateValue(viewmodel.pages$)
  const scale = useStateValue(viewmodel.scale$)
  const pageno = useStateValue(viewmodel.pageno$)
  const pageRefs = React.useRef<Array<HTMLDivElement | null>>([])

  const url = React.useMemo<string>(() => {
    const search = toSearch({ filepath, workspace })
    return `/api/file${search}`
  }, [filepath, workspace])

  React.useEffect(() => {
    pageRefs.current = Array(pages)
      .fill(null)
      .map((_, i) => pageRefs.current[i] || null)
  }, [pages])

  React.useEffect(() => {
    if (multiview && pageRefs.current[pageno - 1]) {
      pageRefs.current[pageno - 1]?.scrollIntoView({
        behavior: 'smooth',
        block: 'start',
      })
    }
  }, [pageno, multiview])

  if (!multiview) {
    return (
      <Page
        pageNumber={pageno}
        scale={scale}
        className="bg-white shadow-lg dark:bg-gray-800"
        loading={
          <div className="h-[600px] w-[450px] animate-pulse rounded bg-gray-200 dark:bg-gray-700" />
        }
      />
    )
  }

  return (
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
      {Array.from(new Array(pages), (_, index) => (
        <div
          key={index}
          ref={el => {
            pageRefs.current[index] = el
          }}
          data-page-number={index + 1}
          className={cn(
            'mb-8 flex justify-center',
            pageno === index + 1 && 'scroll-mt-20 ring-4 ring-blue-400 ring-opacity-50 rounded-lg',
          )}
        >
          <Page
            pageNumber={index + 1}
            scale={scale}
            className="bg-white shadow-lg dark:bg-gray-800"
            loading={
              <div className="h-[600px] w-[450px] animate-pulse rounded bg-gray-200 dark:bg-gray-700" />
            }
          />
        </div>
      ))}
    </Document>
  )
}

Main.displayName = 'PdfViewMain'
