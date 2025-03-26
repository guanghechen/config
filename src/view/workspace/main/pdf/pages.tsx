import cn from 'clsx'
import React from 'react'
import { Page } from 'react-pdf'

interface IProps {
  readonly multiview: boolean
  readonly pages: number
  readonly scale: number
  readonly pageno: number
}

export const PDFPages: React.FC<IProps> = props => {
  const { multiview, pages, scale, pageno } = props
  const pageRefs = React.useRef<Array<HTMLDivElement | null>>([])

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
    <React.Fragment>
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
    </React.Fragment>
  )
}

PDFPages.displayName = 'PDFPages'
