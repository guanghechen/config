import { useStateValue } from '@guanghechen/react-viewmodel'
import cn from 'clsx'
import React from 'react'
import { Document, Page, pdfjs } from 'react-pdf'
import 'react-pdf/dist/Page/AnnotationLayer.css'
import 'react-pdf/dist/Page/TextLayer.css'
import { usePdfViewViewModel } from '../context'

pdfjs.GlobalWorkerOptions.workerSrc = `https://unpkg.com/pdfjs-dist@${pdfjs.version}/build/pdf.worker.min.mjs`

const options = {
  cMapUrl: `https://unpkg.com/pdfjs-dist@${pdfjs.version}/cmaps/`,
}

export const ContentPane: React.FC = () => {
  const viewmodel = usePdfViewViewModel()
  const url: string | null = useStateValue(viewmodel.url$)
  const multiview: boolean = useStateValue(viewmodel.multiview$)
  const pageTotal: number = useStateValue(viewmodel.pageTotal$)
  const scale: number = useStateValue(viewmodel.scale$)
  const pageno: number = useStateValue(viewmodel.pageNo$)

  const pageRefs = React.useRef<Array<HTMLDivElement | null>>([])

  React.useEffect(() => {
    pageRefs.current = Array(pageTotal)
      .fill(null)
      .map((_, i) => pageRefs.current[i] || null)
  }, [pageTotal])

  React.useEffect(() => {
    if (multiview && pageRefs.current[pageno - 1]) {
      pageRefs.current[pageno - 1]?.scrollIntoView({
        behavior: 'smooth',
        block: 'start',
      })
    }
  }, [pageno, multiview])

  const renderPageContent = React.useCallback(() => {
    if (multiview) {
      return Array.from(new Array(pageTotal), (_, index) => (
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
      ))
    }

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
  }, [multiview, pageTotal, pageno, scale])

  if (!url) {
    return <div className="p-4 text-gray-500">No URL provided.</div>
  }

  return (
    <div className="flex h-full w-full flex-col pl-20">
      <div
        className={cn('flex-1', multiview ? 'overflow-auto' : 'flex items-center justify-center')}
      >
        <div className={cn(multiview ? 'flex flex-col items-center pb-8 pt-4' : '')}>
          <Document
            options={options}
            file={url}
            onLoadSuccess={({ numPages }) => viewmodel.pageTotal$.next(numPages)}
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
            {renderPageContent()}
          </Document>
        </div>
      </div>
    </div>
  )
}

ContentPane.displayName = 'PdfViewContentPane'
