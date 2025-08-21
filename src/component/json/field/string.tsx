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

type IPrettierMode = 'plain' | 'md' | 'json' | 'base64img'

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
  private dropdownRef = React.createRef<HTMLDivElement>()

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
    const { isOverflowing, prettier, prettierMode } = this.state
    const expanded: boolean = prettier || this.state.expanded
    const indentStyle: React.CSSProperties = { paddingLeft: `${depth * 1.5}rem` }

    // Check if we're showing rich content (not plain text)
    const isRichContent = prettier && prettierMode !== 'plain'

    if (isRichContent) {
      // Rich content layout: buttons after colon, content below
      return (
        <div className={classes.container.string} style={indentStyle}>
          {/* Key with inline buttons for rich content */}
          <JsonFieldKey name={name}>
            <div className="flex items-center gap-1">
              <div className="relative flex items-center invisible group-hover:visible">
                {/* Connected button group */}
                <div className="flex">
                  {/* Snippet icon - directly applies 'plain' mode */}
                  <button
                    onClick={this.applyPlainMode}
                    className={`rounded-l p-1 transition-colors ${
                      prettier && prettierMode === 'plain'
                        ? 'bg-emerald-100 dark:bg-emerald-900/40 text-emerald-700 dark:text-emerald-300 hover:bg-emerald-200 dark:hover:bg-emerald-800/60'
                        : 'text-gray-400 dark:text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-700 hover:text-gray-600 dark:hover:text-gray-300'
                    }`}
                    aria-label="Apply plain formatting"
                    title="Show plain formatted text"
                  >
                    <SnippetIcon className="h-4 w-4" />
                  </button>

                  {/* Dropdown arrow button */}
                  <button
                    onClick={this.toggleDropdown}
                    className={`rounded-r p-1 transition-colors ${
                      this.state.dropdownOpen
                        ? 'bg-emerald-100 dark:bg-emerald-900/40 text-emerald-700 dark:text-emerald-300'
                        : 'text-gray-400 dark:text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-700 hover:text-gray-600 dark:hover:text-gray-300'
                    }`}
                    aria-label="Toggle view options"
                    title="Select view mode"
                  >
                    {this.state.dropdownOpen ? (
                      <ChevronUpIcon className="h-4 w-4" />
                    ) : (
                      <ChevronDownIcon className="h-4 w-4" />
                    )}
                  </button>
                </div>

                {/* Dropdown menu */}
                {this.state.dropdownOpen && (
                  <div
                    ref={this.dropdownRef}
                    className="absolute top-full right-0 mt-1 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-md shadow-lg z-50 min-w-32 flex flex-col"
                  >
                    <button
                      onClick={() => this.selectMode('plain')}
                      className={`w-full text-left px-3 py-2 text-sm hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors ${
                        prettier && prettierMode === 'plain'
                          ? 'bg-emerald-50 dark:bg-emerald-900/20 text-emerald-700 dark:text-emerald-300'
                          : 'text-gray-700 dark:text-gray-300'
                      }`}
                    >
                      Plain
                    </button>
                    <button
                      onClick={() => this.selectMode('md')}
                      className={`w-full text-left px-3 py-2 text-sm hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors ${
                        prettier && prettierMode === 'md'
                          ? 'bg-emerald-50 dark:bg-emerald-900/20 text-emerald-700 dark:text-emerald-300'
                          : 'text-gray-700 dark:text-gray-300'
                      }`}
                    >
                      Markdown
                    </button>
                    <button
                      onClick={() => this.selectMode('json')}
                      className={`w-full text-left px-3 py-2 text-sm hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors ${
                        prettier && prettierMode === 'json'
                          ? 'bg-emerald-50 dark:bg-emerald-900/20 text-emerald-700 dark:text-emerald-300'
                          : 'text-gray-700 dark:text-gray-300'
                      }`}
                    >
                      JSON
                    </button>
                    <button
                      onClick={() => this.selectMode('base64img')}
                      className={`w-full text-left px-3 py-2 text-sm hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors ${
                        prettier && prettierMode === 'base64img'
                          ? 'bg-emerald-50 dark:bg-emerald-900/20 text-emerald-700 dark:text-emerald-300'
                          : 'text-gray-700 dark:text-gray-300'
                      }`}
                    >
                      Image base64
                    </button>
                  </div>
                )}
              </div>
              <JsonFieldCopyButton value={value} inline={true} />
            </div>
          </JsonFieldKey>

          {/* Content area - full width on next line for rich content */}
          <div className="flex flex-col w-full mt-1 ml-0">
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
                className="mt-1 flex items-center gap-1 self-center rounded-full bg-emerald-50/80 dark:bg-emerald-900/30 px-2 py-0.5 text-xs text-emerald-600 dark:text-emerald-400 transition-colors hover:bg-emerald-100 dark:hover:bg-emerald-800/40 hover:text-emerald-700 dark:hover:text-emerald-300"
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
        </div>
      )
    } else {
      // Plain text layout: buttons on the right side of the string value
      return (
        <div className={classes.container.string} style={indentStyle}>
          <div className="flex items-start group">
            {/* Key and content flowing together */}
            <JsonFieldKey name={name} />
            <div className="flex items-start min-w-0 max-w-full overflow-hidden">
              <div className="flex-shrink min-w-0 overflow-hidden">
                <TextContent
                  value={value}
                  prettier={prettier}
                  prettierMode={prettierMode as TPrettierMode}
                  expanded={expanded}
                  textRef={this.textRef}
                />
              </div>

              {/* Buttons right after the content */}
              <div className="flex items-center gap-1 ml-2 invisible group-hover:visible flex-shrink-0">
                <div className="relative flex items-center">
                  {/* Connected button group */}
                  <div className="flex">
                    {/* Snippet icon - directly applies 'plain' mode */}
                    <button
                      onClick={this.applyPlainMode}
                      className={`rounded-l p-1 transition-colors ${
                        prettier && prettierMode === 'plain'
                          ? 'bg-emerald-100 dark:bg-emerald-900/40 text-emerald-700 dark:text-emerald-300 hover:bg-emerald-200 dark:hover:bg-emerald-800/60'
                          : 'text-gray-400 dark:text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-700 hover:text-gray-600 dark:hover:text-gray-300'
                      }`}
                      aria-label="Apply plain formatting"
                      title="Show plain formatted text"
                    >
                      <SnippetIcon className="h-4 w-4" />
                    </button>

                    {/* Dropdown arrow button */}
                    <button
                      onClick={this.toggleDropdown}
                      className={`rounded-r p-1 transition-colors ${
                        this.state.dropdownOpen
                          ? 'bg-emerald-100 dark:bg-emerald-900/40 text-emerald-700 dark:text-emerald-300'
                          : 'text-gray-400 dark:text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-700 hover:text-gray-600 dark:hover:text-gray-300'
                      }`}
                      aria-label="Toggle view options"
                      title="Select view mode"
                    >
                      {this.state.dropdownOpen ? (
                        <ChevronUpIcon className="h-4 w-4" />
                      ) : (
                        <ChevronDownIcon className="h-4 w-4" />
                      )}
                    </button>
                  </div>

                  {/* Dropdown menu */}
                  {this.state.dropdownOpen && (
                    <div
                      ref={this.dropdownRef}
                      className="absolute top-full right-0 mt-1 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-md shadow-lg z-50 min-w-32 flex flex-col"
                    >
                      <button
                        onClick={() => this.selectMode('plain')}
                        className={`w-full text-left px-3 py-2 text-sm hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors ${
                          prettier && prettierMode === 'plain'
                            ? 'bg-emerald-50 dark:bg-emerald-900/20 text-emerald-700 dark:text-emerald-300'
                            : 'text-gray-700 dark:text-gray-300'
                        }`}
                      >
                        Plain
                      </button>
                      <button
                        onClick={() => this.selectMode('md')}
                        className={`w-full text-left px-3 py-2 text-sm hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors ${
                          prettier && prettierMode === 'md'
                            ? 'bg-emerald-50 dark:bg-emerald-900/20 text-emerald-700 dark:text-emerald-300'
                            : 'text-gray-700 dark:text-gray-300'
                        }`}
                      >
                        Markdown
                      </button>
                      <button
                        onClick={() => this.selectMode('json')}
                        className={`w-full text-left px-3 py-2 text-sm hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors ${
                          prettier && prettierMode === 'json'
                            ? 'bg-emerald-50 dark:bg-emerald-900/20 text-emerald-700 dark:text-emerald-300'
                            : 'text-gray-700 dark:text-gray-300'
                        }`}
                      >
                        JSON
                      </button>
                      <button
                        onClick={() => this.selectMode('base64img')}
                        className={`w-full text-left px-3 py-2 text-sm hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors ${
                          prettier && prettierMode === 'base64img'
                            ? 'bg-emerald-50 dark:bg-emerald-900/20 text-emerald-700 dark:text-emerald-300'
                            : 'text-gray-700 dark:text-gray-300'
                        }`}
                      >
                        Image base64
                      </button>
                    </div>
                  )}
                </div>
                <JsonFieldCopyButton value={value} inline={true} />
              </div>
            </div>
          </div>

          {/* Expand/collapse button for plain text if needed */}
          {isOverflowing && (
            <button
              onClick={this.toggleExpand}
              className="mt-1 flex items-center gap-1 self-center rounded-full bg-emerald-50/80 dark:bg-emerald-900/30 px-2 py-0.5 text-xs text-emerald-600 dark:text-emerald-400 transition-colors hover:bg-emerald-100 dark:hover:bg-emerald-800/40 hover:text-emerald-700 dark:hover:text-emerald-300"
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
      )
    }
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
    document.addEventListener('mousedown', this.handleClickOutside)
  }

  public override componentWillUnmount(): void {
    document.removeEventListener('mousedown', this.handleClickOutside)
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

  protected applyPlainMode = (): void => {
    this.setState({
      prettier: true,
      prettierMode: 'plain',
      dropdownOpen: false,
    })
  }

  protected toggleDropdown = (): void => {
    this.setState(prevState => ({
      dropdownOpen: !prevState.dropdownOpen,
    }))
  }

  protected selectMode = (mode: IPrettierMode): void => {
    this.setState({
      prettier: true,
      prettierMode: mode,
      dropdownOpen: false,
    })
  }

  protected handleClickOutside = (event: MouseEvent): void => {
    if (this.dropdownRef.current && !this.dropdownRef.current.contains(event.target as Node)) {
      this.setState({ dropdownOpen: false })
    }
  }
}
