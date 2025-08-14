import React from 'react'
import { ChevronDownIcon, ChevronUpIcon, SnippetIcon } from '../../icon/material'
import { classes } from '../constant'
import { ImageContent } from '../container/ImageContent'
import type { TPrettierMode } from '../container/TextContent'
import { TextContent } from '../container/TextContent'
import { JsonFieldCopyButton } from '../FieldCopyButton'
import { JsonFieldKey } from '../FieldKey'

interface IProps {
  readonly name: string | number | null
  readonly value: string
  readonly depth: number
}

type IPrettierMode = 'plain' | 'md' | 'base64img'

interface IState {
  readonly expanded: boolean
  readonly isOverflowing: boolean
  readonly prettier: boolean
  readonly prettierMode: IPrettierMode
  readonly dropdownOpen: boolean
}

export class JsonFieldString extends React.Component<IProps, IState> {
  public static displayName = 'JsonFieldString'
  private textRef = React.createRef<HTMLElement | null>()

  constructor(props: IProps) {
    super(props)
    this.state = {
      expanded: false,
      isOverflowing: false,
      prettier: false,
      prettierMode: 'plain',
      dropdownOpen: false,
    }
  }

  public override render(): React.ReactElement {
    const { name, value, depth } = this.props
    const { isOverflowing, prettier, prettierMode, dropdownOpen } = this.state
    const expanded: boolean = prettier || this.state.expanded
    const indentStyle: React.CSSProperties = { paddingLeft: `${depth * 1.5}rem` }

    return (
      <div className={classes.container.string} style={indentStyle}>
        <JsonFieldKey name={name} />
        <div className="flex flex-col">
          {prettier && prettierMode === 'base64img' ? (
            <ImageContent value={value} textRef={this.textRef} />
          ) : (
            <TextContent
              value={value}
              prettier={prettier}
              prettierMode={prettierMode as TPrettierMode}
              expanded={expanded}
              textRef={this.textRef}
            />
          )}
          {isOverflowing && (
            <button
              onClick={this.toggleExpand}
              className="mt-1 flex items-center gap-1 self-start rounded-full bg-emerald-50/80 dark:bg-emerald-900/30 px-2 py-0.5 text-xs text-emerald-600 dark:text-emerald-400 transition-colors hover:bg-emerald-100 dark:hover:bg-emerald-800/40 hover:text-emerald-700 dark:hover:text-emerald-300"
              aria-label={expanded ? 'Show less' : 'Show more'}
            >
              {expanded ? (
                <React.Fragment>
                  <ChevronUpIcon className="h-3.5 w-3.5" />
                  <span>Collapse</span>
                </React.Fragment>
              ) : (
                <React.Fragment>
                  <ChevronDownIcon className="h-3.5 w-3.5" />
                  <span>Expand</span>
                </React.Fragment>
              )}
            </button>
          )}
        </div>
        <div className="flex gap">
          <div className="relative flex items-center invisible group-hover:visible">
            <button
              onClick={this.togglePrettier}
              className={`rounded p-1 transition-colors ${
                prettier
                  ? 'bg-emerald-100 dark:bg-emerald-900/40 text-emerald-700 dark:text-emerald-300 hover:bg-emerald-200 dark:hover:bg-emerald-800/60'
                  : 'text-gray-400 dark:text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-700 hover:text-gray-600 dark:hover:text-gray-300'
              }`}
              aria-label={prettier ? 'Disable prettier' : 'Enable prettier'}
              title={prettier ? 'Show escaped characters' : 'Show formatted text'}
            >
              <SnippetIcon className="h-4 w-4" />
            </button>
            {prettier && (
              <button
                onClick={this.toggleDropdown}
                className="rounded p-1 transition-colors text-gray-400 dark:text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-700 hover:text-gray-600 dark:hover:text-gray-300"
                aria-label="Select prettier mode"
                title="Select prettier mode"
              >
                <ChevronDownIcon className="h-3 w-3" />
              </button>
            )}
            {prettier && dropdownOpen && (
              <div className="absolute top-full right-0 mt-1 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-600 rounded shadow-lg z-10">
                <button
                  onClick={() => this.setPrettierMode('plain')}
                  className={`block w-full px-3 py-2 text-left text-sm hover:bg-gray-100 dark:hover:bg-gray-700 ${
                    prettierMode === 'plain'
                      ? 'bg-emerald-50 dark:bg-emerald-900/20 text-emerald-700 dark:text-emerald-300'
                      : 'text-gray-700 dark:text-gray-300'
                  }`}
                >
                  Plain
                </button>
                <button
                  onClick={() => this.setPrettierMode('md')}
                  className={`block w-full px-3 py-2 text-left text-sm hover:bg-gray-100 dark:hover:bg-gray-700 ${
                    prettierMode === 'md'
                      ? 'bg-emerald-50 dark:bg-emerald-900/20 text-emerald-700 dark:text-emerald-300'
                      : 'text-gray-700 dark:text-gray-300'
                  }`}
                >
                  Markdown
                </button>
                <button
                  onClick={() => this.setPrettierMode('base64img')}
                  className={`block w-full px-3 py-2 text-left text-sm hover:bg-gray-100 dark:hover:bg-gray-700 ${
                    prettierMode === 'base64img'
                      ? 'bg-emerald-50 dark:bg-emerald-900/20 text-emerald-700 dark:text-emerald-300'
                      : 'text-gray-700 dark:text-gray-300'
                  }`}
                >
                  Image (base64)
                </button>
              </div>
            )}
          </div>
          <JsonFieldCopyButton value={value} />
        </div>
      </div>
    )
  }

  public override shouldComponentUpdate(nextProps: IProps, nextState: IState): boolean {
    const props: IProps = this.props
    const state: IState = this.state
    return (
      props.name !== nextProps.name ||
      props.value !== nextProps.value ||
      props.depth !== nextProps.depth ||
      state.expanded !== nextState.expanded ||
      state.isOverflowing !== nextState.isOverflowing ||
      state.prettier !== nextState.prettier ||
      state.prettierMode !== nextState.prettierMode ||
      state.dropdownOpen !== nextState.dropdownOpen
    )
  }

  public override componentDidMount(): void {
    this.checkIfOverflowing()
  }

  public override componentDidUpdate(prevProps: IProps): void {
    if (prevProps.value !== this.props.value) {
      this.checkIfOverflowing()
    }
  }

  protected checkIfOverflowing = (): void => {
    const element = this.textRef.current
    if (element) {
      const isOverflowing = element.scrollHeight > element.clientHeight
      if (isOverflowing !== this.state.isOverflowing) {
        this.setState({ isOverflowing })
      }
    }
  }

  protected toggleExpand = (): void => {
    this.setState(prevState => ({ expanded: !prevState.expanded }))
  }

  protected togglePrettier = (): void => {
    this.setState(prevState => ({ prettier: !prevState.prettier, dropdownOpen: false }))
  }

  protected toggleDropdown = (): void => {
    this.setState(prevState => ({ dropdownOpen: !prevState.dropdownOpen }))
  }

  protected setPrettierMode = (mode: IPrettierMode): void => {
    this.setState({ prettierMode: mode, dropdownOpen: false })
  }
}
