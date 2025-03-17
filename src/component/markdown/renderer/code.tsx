import { css } from '@emotion/css'
import { useStateValue } from '@guanghechen/react-viewmodel'
import type { Code } from '@yozora/ast'
import React, { useState } from 'react'
import { CodeIcon, TerminalIcon } from '@/component/icon/material'
import type { ICodeMetaData } from '@/util/parseCodeMeta'
import { parseCodeMeta } from '@/util/parseCodeMeta'
import { useNodeRendererContext } from '../context'
import { CodeLiveRenderer } from './inner/CodeLive'
import { CodeRendererInner } from './inner/CodeRendererInner'

/**
 * Render `code`
 *
 * @see https://www.npmjs.com/package/@yozora/ast#code
 * @see https://www.npmjs.com/package/@yozora/tokenizer-indented-code
 * @see https://www.npmjs.com/package/@yozora/tokenizer-fenced-code
 */
export const CodeRenderer: React.FC<Code> = props => {
  const { lang } = props
  const value: string = props.value.replace(/[\n\r]+$/, '') // Remove trailing line endings.

  const { viewmodel } = useNodeRendererContext()
  const showCodeLineno: boolean = useStateValue(viewmodel.showCodeLineno$)
  const themeScheme: string = useStateValue(viewmodel.themeScheme$)
  const darken: boolean = themeScheme === 'darken'
  const [isSourceExpanded, setIsSourceExpanded] = useState(false)
  const [isResultExpanded, setIsResultExpanded] = useState(true)

  const classes = useStyles({ darken, isResultExpanded, isSourceExpanded })

  const meta: ICodeMetaData = React.useMemo<ICodeMetaData>(
    () => parseCodeMeta(props.meta || '', { showCodeLineno }),
    [props.meta],
  )

  const toggleSourceExpanded = React.useCallback(() => setIsSourceExpanded(v => !v), [])
  const toggleResultExpanded = React.useCallback(() => setIsResultExpanded(v => !v), [])
  const title: string = (meta.filename || meta.title || '') as string

  if (!lang || !meta.live) {
    return (
      <CodeRendererInner
        darken={darken}
        lang={lang || ''}
        value={value}
        preferCodeWrap={false}
        showCodeLineno={showCodeLineno}
      />
    )
  }

  return (
    <div className={classes.container}>
      <div className={classes.sourceContainer}>
        <div className={classes.sourceHeader} onClick={toggleSourceExpanded}>
          <div className={classes.headerGroup}>
            <CodeIcon className={classes.headerIcon} />
            <span className={classes.langBadge}>{lang}</span>
            {title && <span className={classes.fileName}>{title}</span>}
          </div>
        </div>
        {isSourceExpanded && (
          <div className="source-content">
            <CodeRendererInner
              darken={darken}
              lang={lang}
              value={value}
              preferCodeWrap={false}
              showCodeLineno={showCodeLineno}
              style={{ marginBottom: 0 }}
            />
          </div>
        )}
      </div>
      <div className={classes.resultContainer}>
        <div className={classes.resultHeader} onClick={toggleResultExpanded}>
          <div className={classes.headerGroup}>
            <TerminalIcon className={classes.headerIcon} />
            <span className={classes.resultLabel}>Result</span>
          </div>
        </div>
        {isResultExpanded && (
          <div className={classes.resultContent}>
            <CodeLiveRenderer lang={lang} code={value} meta={meta} />
          </div>
        )}
      </div>
    </div>
  )
}

const useStyles = (params: {
  darken: boolean
  isSourceExpanded: boolean
  isResultExpanded: boolean
}) => {
  const { darken, isSourceExpanded, isResultExpanded } = params
  return React.useMemo(
    () => ({
      container: css({
        margin: '1rem 0',
        borderRadius: '8px',
        overflow: 'hidden',
        boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
      }),
      sourceContainer: css({
        borderBottom: isSourceExpanded ? '1px solid rgba(0,0,0,0.1)' : 'none',
      }),
      sourceHeader: css({
        padding: '8px 16px',
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        cursor: 'pointer',
        backgroundColor: darken ? '#2d2d2d' : '#f5f5f5',
        borderBottom: isSourceExpanded ? '1px solid rgba(0,0,0,0.1)' : 'none',
        userSelect: 'none',
      }),
      headerGroup: css({
        display: 'flex',
        alignItems: 'center',
        gap: '8px',
      }),
      headerIcon: css({
        width: '18px',
        height: '18px',
        opacity: 0.8,
      }),
      langBadge: css({
        padding: '2px 6px',
        borderRadius: '4px',
        backgroundColor: darken ? '#444' : '#e0e0e0',
        fontSize: '0.8rem',
      }),
      fileName: css({
        fontSize: '0.9rem',
      }),
      toggleText: css({
        fontSize: '0.8rem',
        opacity: 0.7,
      }),
      resultContainer: css({
        // Result container styling
      }),
      resultHeader: css({
        padding: '8px 16px',
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        cursor: 'pointer',
        backgroundColor: darken ? '#2d2d2d' : '#f5f5f5',
        borderBottom: isResultExpanded ? '1px solid rgba(0,0,0,0.1)' : 'none',
        userSelect: 'none',
      }),
      resultLabel: css({
        fontSize: '0.9rem',
      }),
      resultContent: css({
        padding: '16px',
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
      }),
    }),
    [darken, isSourceExpanded, isResultExpanded],
  )
}
