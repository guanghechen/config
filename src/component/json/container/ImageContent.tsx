import React from 'react'

interface IProps {
  readonly value: string
  readonly textRef: React.RefObject<HTMLElement | null>
}

interface IImageState {
  readonly isValidImage: boolean
  readonly imageError: boolean
}

export class ImageContent extends React.Component<IProps, IImageState> {
  public static displayName = 'ImageContent'

  constructor(props: IProps) {
    super(props)
    this.state = {
      isValidImage: this.detectBase64Image(props.value),
      imageError: false,
    }
  }

  public override componentDidUpdate(prevProps: IProps): void {
    if (prevProps.value !== this.props.value) {
      this.setState({
        isValidImage: this.detectBase64Image(this.props.value),
        imageError: false,
      })
    }
  }

  private detectBase64Image(value: string): boolean {
    if (!value || typeof value !== 'string') return false

    const base64Pattern = /^data:image\/(png|jpeg|jpg|gif|webp|svg\+xml);base64,/i
    if (base64Pattern.test(value)) return true

    const pureBase64Pattern = /^[A-Za-z0-9+/]+=*$/
    if (pureBase64Pattern.test(value) && value.length > 100) {
      try {
        const decoded = atob(value.substring(0, 100))
        const isPNG = decoded.startsWith('\x89PNG')
        const isJPEG = decoded.startsWith('\xFF\xD8\xFF')
        const isGIF = decoded.startsWith('GIF87a') || decoded.startsWith('GIF89a')
        const isWebP = decoded.includes('WEBP')
        return isPNG || isJPEG || isGIF || isWebP
      } catch {
        return false
      }
    }

    return false
  }

  private handleImageError = (): void => {
    this.setState({ imageError: true })
  }

  private getImageSrc(): string {
    const { value } = this.props
    if (value.startsWith('data:image/')) {
      return value
    }
    return `data:image/png;base64,${value}`
  }

  public override render(): React.ReactElement {
    const { value, textRef } = this.props
    const { isValidImage, imageError } = this.state

    if (!isValidImage || imageError) {
      return (
        <code
          ref={textRef}
          className="overflow-hidden text-emerald-600 dark:text-emerald-400 break-all"
        >
          "{value.replace(/\n/g, '\\n')}"
        </code>
      )
    }

    return (
      <div className="flex flex-col gap-2">
        <div className="overflow-hidden rounded border border-gray-200 dark:border-gray-600">
          <img
            src={this.getImageSrc()}
            alt="Base64 encoded content"
            className="max-w-full h-auto"
            onError={this.handleImageError}
            style={{ maxHeight: '12rem' }}
          />
        </div>
      </div>
    )
  }

  public override shouldComponentUpdate(nextProps: IProps, nextState: IImageState): boolean {
    const props: IProps = this.props
    const state: IImageState = this.state
    return (
      props.value !== nextProps.value ||
      state.isValidImage !== nextState.isValidImage ||
      state.imageError !== nextState.imageError
    )
  }
}
