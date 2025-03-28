import cn from 'clsx'
import React from 'react'

interface IProps {
  src: string
  alt: string
  title: string | undefined
  srcSet: string | undefined
  sizes: string | undefined
  loading: 'eager' | 'lazy' | undefined
  className: string
}

export class ImageRendererInner extends React.Component<IProps> {
  public static displayName = 'ImageRendererInner'

  public override render(): React.ReactElement {
    const { src, alt, title, srcSet, sizes, loading, className } = this.props
    const { width, height } = this.parseImageDimensions(src)
    const figureStyle: React.CSSProperties = { width, height }

    return (
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
          className="box-border flex-1 border border-purple-600 object-contain shadow-[0_0_20px_1px_rgba(126,125,150,0.6)]"
        />
        {title && (
          <figcaption className="text-center text-base italic text-gray-500">{title}</figcaption>
        )}
      </figure>
    )
  }

  public override shouldComponentUpdate(nextProps: IProps): boolean {
    const props = this.props
    return (
      props.src !== nextProps.src ||
      props.alt !== nextProps.alt ||
      props.title !== nextProps.title ||
      props.srcSet !== nextProps.srcSet ||
      props.sizes !== nextProps.sizes ||
      props.loading !== nextProps.loading ||
      props.className !== nextProps.className
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
}
