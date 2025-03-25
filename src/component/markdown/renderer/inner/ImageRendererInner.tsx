import { css } from '@emotion/css'
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
      <figure className={cn(className, cls)} style={figureStyle}>
        <img
          alt={alt}
          src={src}
          title={title}
          srcSet={srcSet}
          sizes={sizes}
          loading={loading}
          width={width}
          height={height}
        />
        {title && <figcaption>{title}</figcaption>}
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

const cls = css({
  boxSizing: 'border-box',
  maxWidth: '80%', // Prevent images from overflowing the container.
  display: 'flex',
  flexDirection: 'column',
  alignItems: 'center',
  margin: 0,
  '> img': {
    flex: '1 0 auto',
    boxSizing: 'border-box',
    maxWidth: '100%',
    objectFit: 'contain',
    border: '1px solid var(--colorBorderImage)',
    boxShadow: '0 0 20px 1px rgba(126, 125, 150, 0.6)',
  },
  '> figcaption': {
    textAlign: 'center',
    fontStyle: 'italic',
    fontSize: '1em',
    color: 'var(--colorImageTitle)',
  },
})
