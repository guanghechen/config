import { css, cx } from '@emotion/css';
import { useDeepCompareEffect, useDeepCompareMemo } from '@guanghechen/react-hooks';
import { useComputed } from '@guanghechen/react-viewmodel';
import type { Definition, Root } from '@yozora/ast';
import React from 'react';
import { AstRenderer } from './AstRenderer';
import type {
  INodeRendererContext,
  INodeRendererMap,
  IReactMarkdownThemeScheme,
} from './context';
import {
  NodeRendererContextType,
  ReactMarkdownViewModel,
  astClasses,
} from './context';
import { useMarkdownTheme } from './hook/useMarkdownTheme';
import { buildNodeRendererMap } from './renderer';

export interface IMarkdownProps {
  /**
   * Text content of markdown.
   */
  readonly text: string | string[];
  /**
   * Customized node renderer mpa.
   */
  readonly customizedRendererMap?: Readonly<Partial<INodeRendererMap>>;
  /**
   * Preset Link / Image reference definitions.
   */
  readonly presetDefinitionMap?: Readonly<Record<string, Definition>>;
  /**
   * Whether if show lineno for code block.
   */
  readonly showCodeLineno?: boolean;
  /**
   * Custom behavior instead of opening the link in a new tab.
   */
  readonly onClickAnchor?: React.MouseEventHandler<HTMLAnchorElement>;
  /**
   * Root css class of the component.
   */
  className?: string;
  /**
   * Root css style.
   */
  style?: React.CSSProperties;
}

export const ReactMarkdown: React.FC<IMarkdownProps> = (props) => {
  const themeScheme: IReactMarkdownThemeScheme = useMarkdownTheme();
  const {
    onClickAnchor,
    customizedRendererMap,
    showCodeLineno = true,
    text,
    className,
    style,
  } = props;

  const presetDefinitionMap: Record<
    string,
    Readonly<Definition>
  > = useDeepCompareMemo(
    () => props.presetDefinitionMap ?? {},
    [props.presetDefinitionMap],
  );
  const [viewmodel] = React.useState<ReactMarkdownViewModel>(() => {
    const texts: string[] = Array.isArray(text) ? text : [text];
    return new ReactMarkdownViewModel({
      texts,
      rendererMap: buildNodeRendererMap(customizedRendererMap),
      presetDefinitionMap,
      showCodeLineno,
      themeScheme,
    });
  });

  const context = React.useMemo<INodeRendererContext>(
    () => ({ viewmodel, onClickAnchor }),
    [viewmodel, onClickAnchor],
  );

  const cls: string = cx(
    rootCls,
    themeScheme === 'darken' && astClasses.rootDarken,
    className,
  );

  useDeepCompareEffect(() => {
    const texts: string[] = Array.isArray(text) ? text : [text];
    viewmodel.setContent(texts);
  }, [viewmodel, props.text]);

  React.useEffect(() => {
    viewmodel.showCodeLineno$.next(showCodeLineno);
  }, [viewmodel, showCodeLineno]);

  React.useEffect(() => {
    viewmodel.themeScheme$.next(themeScheme);
  }, [viewmodel, themeScheme]);

  const asts: Root[] = useComputed(viewmodel.asts$);
  return (
    <div className={cls} style={style}>
      <NodeRendererContextType.Provider value={context}>
        {asts.map((ast, index) => (
          <AstRenderer key={index} index={index} ast={ast} />
        ))}
      </NodeRendererContextType.Provider>
    </div>
  );
};

const rootCls = cx(
  astClasses.root,
  css({
    wordBreak: 'break-all',
    userSelect: 'unset',
    fontFamily:
      'Ginto-Copilot-Upright-Variable, -apple-system, "system-ui", Roboto, "Helvetica Neue", sans-serif',
    [astClasses.listItem]: {
      [`> ${astClasses.list}`]: {
        marginLeft: '1.2em',
      },
    },
    '> :last-child': {
      marginBottom: 0,
    },
  }),
);
