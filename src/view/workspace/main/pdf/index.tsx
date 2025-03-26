import cn from 'clsx'
import React from 'react'
import { Document, pdfjs } from 'react-pdf'
import 'react-pdf/dist/esm/Page/AnnotationLayer.css'
import 'react-pdf/dist/esm/Page/TextLayer.css'
import { PRESET_CLASSES } from '@/constant/classes'
import { toSearch } from '@/util/url'
import { PDFPages } from './pages'
import { PDFToolbar } from './toolbar'

pdfjs.GlobalWorkerOptions.workerSrc = new URL(
  'pdfjs-dist/build/pdf.worker.min.mjs',
  import.meta.url,
).toString()

const options = {
  cMapUrl: `https://unpkg.com/pdfjs-dist@${pdfjs.version}/cmaps/`,
}

interface IProps {
  readonly workspace: string | null
  readonly filepath: string | null
}

export const PDFContainer: React.FC<IProps> = props => {
  const { filepath, workspace } = props
  const [pages, setPages] = React.useState<number>(1)
  const [pageno, setPageno] = React.useState<number>(1)
  const [scale, setScale] = React.useState<number>(1)
  const [multiview, setMultiview] = React.useState<boolean>(false)

  const url = React.useMemo<string>(() => {
    const search = toSearch({ filepath, workspace })
    return `/api/file${search}`
  }, [filepath, workspace])

  return (
    <div className="flex h-full flex-col bg-gray-50 dark:bg-gray-900">
      <div className="sticky top-0 z-10 mb-4 flex-initial flex-shrink-0">
        <PDFToolbar
          filepath={filepath}
          pages={pages}
          pageno={pageno}
          scale={scale}
          multiview={multiview}
          setPageno={setPageno}
          setScale={setScale}
          setMultiview={setMultiview}
          className="w-full"
        />
      </div>
      <div
        className={cn('flex flex-auto justify-center overflow-auto p-4', PRESET_CLASSES.scrollbar)}
      >
        <Document
          options={options}
          file={url}
          onLoadSuccess={({ numPages }) => setPages(numPages)}
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
          <PDFPages multiview={multiview} pages={pages} scale={scale} pageno={pageno} />
        </Document>
      </div>
    </div>
  )
}

PDFContainer.displayName = 'PDFContainer'
export default PDFContainer
