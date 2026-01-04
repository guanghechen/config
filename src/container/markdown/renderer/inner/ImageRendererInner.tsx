import cn from 'clsx'
import React from 'react'
import { ImageViewer } from './ImageViewer'

interface IProps {
  readonly src: string
  readonly alt: string
  readonly title: string | undefined
  readonly srcSet: string | undefined
  readonly sizes: string | undefined
  readonly loading: 'eager' | 'lazy' | undefined
  readonly className: string
}

interface IState {
  readonly isFullscreen: boolean
}

export class ImageRendererInner extends React.Component<IProps, IState> {
  public static displayName = 'ImageRendererInner'

  constructor(props: IProps) {
    super(props)

    this.state = {
      isFullscreen: false,
    }
  }

  public override render(): React.ReactElement {
    const { src, alt, title, srcSet, sizes, loading, className } = this.props
    const { isFullscreen } = this.state
    const { width, height } = this.parseImageDimensions(src)
    const figureStyle: React.CSSProperties = { width, height }

    return (
      <React.Fragment>
        <figure
          className={cn(className, 'box-border max-w-full flex flex-col items-center m-0 px-8')}
          style={figureStyle}
        >
          <img
            alt={alt}
            src={src}
            title={title}
            srcSet={srcSet}
            sizes={sizes}
            loading={loading}
            width={width}
            height={height}
            className="box-border flex-1 cursor-pointer border border-purple-600 object-contain shadow-[0_0_20px_1px_rgba(126,125,150,0.6)]"
            onClick={this.onOpenFullscreen}
          />
          {title && (
            <figcaption className="text-center text-base italic text-gray-500">{title}</figcaption>
          )}
        </figure>

        <ImageViewer src={src} alt={alt} open={isFullscreen} onClose={this.onCloseFullscreen} />
      </React.Fragment>
    )
  }

  public override shouldComponentUpdate(nextProps: IProps, nextState: IState): boolean {
    const props = this.props
    const state = this.state
    return (
      props.src !== nextProps.src ||
      props.alt !== nextProps.alt ||
      props.title !== nextProps.title ||
      props.srcSet !== nextProps.srcSet ||
      props.sizes !== nextProps.sizes ||
      props.loading !== nextProps.loading ||
      props.className !== nextProps.className ||
      state.isFullscreen !== nextState.isFullscreen
    )
  }

  private parseImageDimensions(src: string): { width?: string; height?: string } {
    try {
      const url = new URL(src)
      const width = url.searchParams.get('width')
      const height = url.searchParams.get('height')

      return {
        width: width || undefined,
        height: height || undefined,
      }
    } catch (_) {
      const urlParams = new URLSearchParams(src.split('?')[1] || '')
      return {
        width: urlParams.get('width') || undefined,
        height: urlParams.get('height') || undefined,
      }
    }
  }

  protected onOpenFullscreen = (e: React.MouseEvent): void => {
    e.stopPropagation()
    this.setState({ isFullscreen: true })
  }

  protected onCloseFullscreen = (): void => {
    this.setState({ isFullscreen: false })
  }
}
