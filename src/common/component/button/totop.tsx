import cn from 'clsx'
import React from 'react'

interface IProps {
  readonly scrollableContainer: HTMLDivElement | null
}

interface IState {
  readonly visible: boolean
}

export class TotopButton extends React.PureComponent<IProps, IState> {
  public static readonly displayName: string = 'TotopButton'

  constructor(props: IProps) {
    super(props)
    this.state = { visible: false }
  }

  public override render(): React.ReactElement {
    const { visible } = this.state

    return (
      <div className="relative inline-block">
        <button
          onClick={this.scrollToTop}
          className={cn(
            'cursor-pointer fixed bottom-8 right-8 z-50 flex h-12 w-12 items-center justify-center rounded-full bg-blue-500 bg-opacity-60 text-white shadow-lg transition-all duration-300 hover:bg-blue-600 hover:bg-opacity-100 dark:bg-blue-600 dark:bg-opacity-70 dark:hover:bg-blue-500 dark:hover:bg-opacity-100',
            visible ? 'translate-y-0 opacity-90' : 'pointer-events-none translate-y-16 opacity-0',
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

  public override componentDidMount(): void {
    this.setupScrollListener()
  }

  public override componentDidUpdate(prevProps: IProps): void {
    if (prevProps.scrollableContainer !== this.props.scrollableContainer) {
      this.cleanupScrollListener(prevProps.scrollableContainer)
      this.setupScrollListener()
    }
  }

  public override componentWillUnmount(): void {
    this.cleanupScrollListener(this.props.scrollableContainer)
  }

  protected readonly setupScrollListener = (): void => {
    const { scrollableContainer } = this.props
    if (!scrollableContainer) return

    this.handleScroll()
    scrollableContainer.addEventListener('scroll', this.handleScroll)
  }

  protected readonly cleanupScrollListener = (container: HTMLDivElement | null): void => {
    if (container) {
      container.removeEventListener('scroll', this.handleScroll)
    }
  }

  protected readonly handleScroll = (): void => {
    const { scrollableContainer } = this.props
    if (!scrollableContainer) return

    const visible = scrollableContainer.scrollTop > 100
    this.setState({ visible })
  }

  protected readonly scrollToTop = (): void => {
    const { scrollableContainer } = this.props
    if (scrollableContainer) {
      scrollableContainer.scrollTo({ top: 0, behavior: 'smooth' })
    }
  }
}
