import { isEqual } from '@guanghechen/equal'
import cn from 'clsx'
import type { TokenStream } from 'prismjs'
import Prism from 'prismjs'
import React from 'react'
import type {
  ILineInputProps,
  ILineOutputProps,
  IPrismTheme,
  IThemeDict,
  IToken,
  ITokenInputProps,
  ITokenOutputProps,
} from '../types'
import { themeToDict } from '../util/theme'
import { normalizeTokens } from '../util/token'

interface IProps {
  readonly code: string
  readonly collapsed: boolean
  readonly language: string
  readonly maxLines: number
  readonly showLineno: boolean
  readonly theme: IPrismTheme
  readonly highlightLinenos: number[]
  readonly className?: string
  readonly codesClassName?: string
}

interface IState {
  readonly linenoWidth: string | undefined
  readonly themeDict: IThemeDict
  readonly tokens: IToken[][]
}

export class HighlightContent extends React.Component<IProps, IState> {
  public static readonly displayName = 'HighlightContent'

  constructor(props: IProps) {
    super(props)

    const themeDict: IThemeDict = themeToDict(props.language, props.theme)
    const tokens: IToken[][] = this.tokenize(props.code, props.language)
    const linenoWidth: string | undefined = props.showLineno
      ? `${Math.max(2, String(tokens.length).length) * 1.1}em`
      : undefined
    this.state = { linenoWidth, themeDict, tokens }
  }

  public override render(): React.ReactElement {
    const {
      collapsed,
      highlightLinenos,
      language,
      maxLines,
      showLineno = true,
      className,
      codesClassName,
    } = this.props
    const { linenoWidth, tokens } = this.state

    const countOfLines: number = tokens.length
    const visibleLines: number = maxLines > 0 ? Math.min(maxLines, countOfLines) : countOfLines

    // Sync lineno width.
    const style: React.CSSProperties = {
      ...this.state.themeDict.root,
      backgroundColor: 'none',
      ...(collapsed
        ? {
            maxHeight: 0,
          }
        : {
            maxHeight: `calc(1.6em * ${visibleLines + 0.8} + 6px)`,
            minHeight: '100%',
          }),
    }

    return (
      <div
        className={cn(
          'overflow-auto w-full text-sm leading-6 p-0 antialiased transition-[max-height] duration-500 ease-in-out tab-[2] font-smooth-always whitespace-pre break-keep',
          language ? `prism-code language-${language}` : 'prism-code',
          className,
        )}
        style={style}
      >
        <div className={cn('min-w-full w-fit p-2', codesClassName)}>
          {tokens.map((line, index) => {
            const lineno: number = index + 1
            const isHighlight = highlightLinenos.includes(lineno)
            const lineProps = this.getLineProps({ line })
            return (
              <div
                {...lineProps}
                key={lineno}
                className={cn(
                  'box-border flex min-w-fit w-full text-sm leading-6 h-6',
                  'break-inherit tab-inherit text-inherit whitespace-inherit',
                  isHighlight && 'bg-amber-500/30 dark:bg-amber-600/30 border-transparent',
                  lineProps.className,
                )}
              >
                {showLineno && (
                  <div
                    className="flex-none cursor-default select-none text-right pr-2 mr-2 border-r border-gray-300 dark:border-gray-600"
                    style={{ width: linenoWidth }}
                  >
                    <span>{lineno}</span>
                  </div>
                )}
                <div className="flex-auto px-3">
                  {line.map((token, key) => (
                    <span {...this.getTokenProps({ token })} key={key} />
                  ))}
                </div>
              </div>
            )
          })}
        </div>
      </div>
    )
  }

  public override shouldComponentUpdate(
    nextProps: Readonly<IProps>,
    nextState: Readonly<IState>,
  ): boolean {
    const props: IProps = this.props
    const state: IState = this.state
    return (
      state.linenoWidth !== nextState.linenoWidth ||
      state.themeDict !== nextState.themeDict ||
      state.tokens !== nextState.tokens ||
      props.code !== nextProps.code ||
      props.collapsed !== nextProps.collapsed ||
      props.language !== nextProps.language ||
      props.maxLines !== nextProps.maxLines ||
      props.showLineno !== nextProps.showLineno ||
      props.className !== nextProps.className ||
      props.codesClassName !== nextProps.codesClassName ||
      !isEqual(props.theme, nextProps.theme) ||
      !isEqual(props.highlightLinenos, nextProps.highlightLinenos)
    )
  }

  public override componentDidUpdate(
    prevProps: Readonly<IProps>,
    prevState: Readonly<IState>,
  ): void {
    const props: IProps = this.props
    const state: IState = this.state

    const latestThemeDict: IThemeDict =
      props.language !== prevProps.language || !isEqual(props.theme, prevProps.theme)
        ? themeToDict(props.language, props.theme)
        : state.themeDict
    if (
      props.code !== prevProps.code ||
      props.language !== prevProps.language ||
      latestThemeDict !== prevState.themeDict
    ) {
      const nextTokens: IToken[][] = this.tokenize(props.code, props.language)
      const linenoWidth: string | undefined = props.showLineno
        ? `${Math.max(2, String(nextTokens.length).length) * 1.1}em`
        : undefined
      this.setState({ linenoWidth, themeDict: latestThemeDict, tokens: nextTokens })
    }
  }

  protected tokenize(code: string, language: string): IToken[][] {
    const grammar = language ? Prism.languages[language] : undefined
    if (grammar) {
      const env = { code, grammar, language, tokens: [] as TokenStream }
      Prism.hooks.run('before-tokenize', env)
      env.tokens = Prism.tokenize(env.code, env.grammar)
      Prism.hooks.run('after-tokenize', env)
      const tokens: IToken[][] = normalizeTokens(env.tokens)
      return tokens
    } else {
      const tokens: IToken[][] = normalizeTokens([code])
      return tokens
    }
  }

  protected getLineProps(lineInputProps: ILineInputProps): ILineOutputProps {
    const { themeDict } = this.state
    const { key, className, style, line, ...rest } = lineInputProps
    const output: ILineOutputProps = {
      ...rest,
      className: 'token-line',
      style: undefined,
      key: undefined,
    }

    if (themeDict !== undefined) {
      output.style = themeDict.plain
    }

    if (style !== undefined) {
      output.style = output.style !== undefined ? { ...output.style, ...style } : style
    }

    if (key !== undefined) output.key = key
    if (className) output.className += ` ${className}`

    return output
  }

  protected getStyleForToken({ types, empty }: IToken): React.CSSProperties | undefined {
    const { themeDict } = this.state
    const typesSize = types.length
    if (themeDict === undefined) {
      return undefined
    } else if (typesSize === 1 && types[0] === 'plain') {
      return empty ? { display: 'inline-block' } : undefined
    } else if (typesSize === 1 && !empty) {
      return themeDict[types[0]]
    }

    const style = empty ? { display: 'inline-block' } : {}
    for (const type of types) {
      const typeStyle = themeDict[type]
      Object.assign(style, typeStyle)
    }
    return style
  }

  protected getTokenProps(tokenInputProps: ITokenInputProps): ITokenOutputProps {
    const { key, className, style, token, ...rest } = tokenInputProps
    const output: ITokenOutputProps = {
      ...rest,
      className: `token ${token.types.join(' ')}`,
      children: token.content,
      style: this.getStyleForToken(token),
      key: undefined,
    }

    if (style !== undefined) {
      output.style = output.style !== undefined ? { ...output.style, ...style } : style
    }
    if (key !== undefined) output.key = key
    if (className) output.className += ` ${className}`
    return output
  }
}
