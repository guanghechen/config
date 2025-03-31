import { useComputed } from '@guanghechen/react-viewmodel'
import React from 'react'
import { ElementViewer } from '@/component/ElementViewer'
import { useMarkdownViewmodel } from '../../context'

interface IProps {
  readonly src: string
  readonly alt: string
  readonly open: boolean
  readonly onClose?: () => void
}

export const ImageViewer: React.FC<IProps> = props => {
  const { src, alt, open, onClose } = props

  const viewmodel = useMarkdownViewmodel()
  const imageList = useComputed(viewmodel.images$)
  const [currentIndex, setCurrentIndex] = React.useState<number>(-1)

  React.useEffect(() => {
    const index = imageList.findIndex(img => img.src === src)
    setCurrentIndex(index)
  }, [src, imageList])

  const navigateToImage = React.useCallback(
    (index: number) => {
      if (imageList.length > 0) {
        if (index < 0) {
          setCurrentIndex(imageList.length - 1)
        } else if (index >= imageList.length) {
          setCurrentIndex(0)
        } else {
          setCurrentIndex(index)
        }
      }
    },
    [imageList],
  )

  const handleClose = React.useCallback(() => {
    onClose?.()
  }, [onClose])

  // Key event handlers for navigation
  React.useEffect(() => {
    if (open) {
      const handleKeyDown = (e: KeyboardEvent): void => {
        if (imageList.length > 1) {
          if (e.key === 'ArrowLeft') {
            e.preventDefault()
            navigateToImage(currentIndex - 1)
          } else if (e.key === 'ArrowRight') {
            e.preventDefault()
            navigateToImage(currentIndex + 1)
          }
        }
      }

      window.addEventListener('keydown', handleKeyDown)
      return () => {
        window.removeEventListener('keydown', handleKeyDown)
      }
    }
  }, [open, imageList, currentIndex, navigateToImage])

  const imageSrc =
    currentIndex >= 0 && currentIndex < imageList.length ? imageList[currentIndex].src : src
  const imageAlt =
    currentIndex >= 0 && currentIndex < imageList.length ? imageList[currentIndex].alt : alt

  return (
    <React.Fragment>
      <ElementViewer open={open} resetOnOpen={true} onClose={handleClose}>
        <img src={imageSrc} alt={imageAlt} className="max-w-[80vw] max-h-[80vh] object-contain" />
      </ElementViewer>
      {open && imageList.length > 1 && (
        <React.Fragment>
          <button
            className="fixed left-4 cursor-pointer top-1/2 z-50 -translate-y-1/2 rounded-full bg-gray-800/70 p-3 text-white backdrop-blur-sm transition-opacity hover:bg-gray-700/90"
            onClick={e => {
              e.stopPropagation()
              navigateToImage(currentIndex - 1)
            }}
            title="Previous image"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="28"
              height="28"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <polyline points="15 18 9 12 15 6" />
            </svg>
          </button>
          <button
            className="fixed right-4 cursor-pointer z-50 top-1/2 -translate-y-1/2 rounded-full bg-gray-800/70 p-3 text-white backdrop-blur-sm transition-opacity hover:bg-gray-700/90"
            onClick={e => {
              e.stopPropagation()
              navigateToImage(currentIndex + 1)
            }}
            title="Next image"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              width="28"
              height="28"
              viewBox="0 0 24 24"
              fill="none"
              stroke="currentColor"
              strokeWidth="2"
              strokeLinecap="round"
              strokeLinejoin="round"
            >
              <polyline points="9 18 15 12 9 6" />
            </svg>
          </button>
        </React.Fragment>
      )}
    </React.Fragment>
  )
}

ImageViewer.displayName = 'ImageViewer'
