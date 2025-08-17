import { isEqual } from '@guanghechen/equal'
import cn from 'clsx'
import type { TokenStream } from 'prismjs'
import Prism from 'prismjs'
import React from 'react'
import { PRESET_CLASSES } from '@/shared/constant/classes'
import type {
  ILineInputProps,
  ILineOutputProps,
  IPrismThemeScheme,
  IThemeDict,
  IToken,
  ITokenInputProps,
  ITokenOutputProps,
} from './types'
import { themeToDict } from './util/theme'
import { normalizeTokens } from './util/token'

interface IProps {
  readonly code: string
  readonly themeScheme: IPrismThemeScheme
  readonly lang?: string
  readonly collapsed?: boolean
  readonly maxLines?: number
  readonly showLineno?: boolean
  readonly highlightLinenos?: number[]
}

interface IState {
  readonly linenoWidth: string | undefined
  readonly themeDict: IThemeDict
  readonly tokens: IToken[][]
}

export class CodeHighlighter extends React.Component<IProps, IState> {
  public static readonly displayName = 'CodeHighlighter'

  constructor(props: IProps) {
    super(props)

    const { code, lang = '', themeScheme, showLineno } = props

    const themeDict: IThemeDict = themeToDict(lang, themeScheme)
    const tokens: IToken[][] = this.tokenize(code, lang)
    const linenoWidth: string | undefined = showLineno
      ? `${Math.max(2, String(tokens.length).length) * 1.1}em`
      : undefined
    this.state = { linenoWidth, themeDict, tokens }
  }

  public override render(): React.ReactElement {
    const {
      collapsed = false,
      highlightLinenos = [],
      lang = '',
      maxLines = -1,
      showLineno = true,
    } = this.props
    const { linenoWidth, tokens } = this.state

    const countOfLines: number = tokens.length

    // Sync lineno width.
    const style: React.CSSProperties = {
      ...this.state.themeDict.root,
      backgroundColor: 'none',
      ...(collapsed
        ? {
            maxHeight: 0,
          }
        : {
            maxHeight:
              maxLines > 0
                ? `calc(1.6em * ${Math.min(maxLines, countOfLines) + 0.8} + 6px)`
                : undefined,
            minHeight: '100%',
          }),
    }

    return (
      <div
        className={cn(
          'w-full text-sm leading-6 p-0 antialiased transition-[max-height] duration-500 ease-in-out tab-[2] font-smooth-always whitespace-pre break-keep',
          lang ? `prism-code language-${lang}` : 'prism-code',
        )}
        style={style}
      >
        <div className={cn('min-w-full w-fit p-0 m-0', PRESET_CLASSES.scrollbar)}>
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
                  isHighlight && 'bg-blue-100/80 dark:bg-blue-900/30',
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
      props.lang !== nextProps.lang ||
      props.maxLines !== nextProps.maxLines ||
      props.showLineno !== nextProps.showLineno ||
      !isEqual(props.themeScheme, nextProps.themeScheme) ||
      !isEqual(props.highlightLinenos, nextProps.highlightLinenos)
    )
  }

  public override componentDidUpdate(
    prevProps: Readonly<IProps>,
    prevState: Readonly<IState>,
  ): void {
    const props: IProps = this.props
    const state: IState = this.state

    const { code, lang = '' } = props

    const latestThemeDict: IThemeDict =
      props.lang !== prevProps.lang || !isEqual(props.themeScheme, prevProps.themeScheme)
        ? themeToDict(lang, props.themeScheme)
        : state.themeDict
    if (
      props.code !== prevProps.code ||
      props.lang !== prevProps.lang ||
      latestThemeDict !== prevState.themeDict
    ) {
      const nextTokens: IToken[][] = this.tokenize(code, lang)
      const linenoWidth: string | undefined = props.showLineno
        ? `${Math.max(2, String(nextTokens.length).length) * 1.1}em`
        : undefined
      this.setState({ linenoWidth, themeDict: latestThemeDict, tokens: nextTokens })
    }
  }

  protected tokenize(code: string, lang: string): IToken[][] {
    const grammar = lang ? Prism.languages[lang] : undefined
    if (grammar) {
      const env = { code, grammar, lang, tokens: [] as TokenStream }
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
