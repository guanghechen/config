import { Computed, State, ViewModel } from '@guanghechen/react-viewmodel';
import { type Definition, type Root } from '@yozora/ast';
import { calcDefinitionMap } from '@yozora/ast-util';
import { parseMarkdown } from '../parser';
import type { INodeRendererMap } from './types';

export type IReactMarkdownThemeScheme = 'lighten' | 'darken' | string;

export interface IReactMarkdownViewModelProps {
  /**
   * Markdown texts.
   */
  readonly texts: string[];
  /**
   * Preset Link / Image reference definitions.
   */
  readonly presetDefinitionMap: Readonly<Record<string, Definition>>;
  /**
   * Ast node renderer map.
   */
  readonly rendererMap: Readonly<INodeRendererMap>;
  /**
   * Whether if show code lineno.
   */
  readonly showCodeLineno: boolean;
  /**
   * React markdown theme scheme.
   */
  readonly themeScheme: IReactMarkdownThemeScheme;
}

export class ReactMarkdownViewModel extends ViewModel {
  public readonly texts$: State<string[]>;
  public readonly rendererMap$: State<Readonly<INodeRendererMap>>;
  public readonly showCodeLineno$: State<boolean>;
  public readonly themeScheme$: State<IReactMarkdownThemeScheme>;
  public readonly asts$: Computed<Root[]>;
  public readonly definitionMap$: Computed<
    Readonly<Record<string, Definition>>
  >;

  constructor(props: IReactMarkdownViewModelProps) {
    super();

    const {
      texts,
      presetDefinitionMap,
      rendererMap,
      showCodeLineno,
      themeScheme,
    } = props;

    const texts$: State<string[]> = new State<string[]>(texts);
    const asts$: Computed<Root[]> = Computed.fromObservables(
      [texts$],
      ([texts]): Root[] =>
        texts.map((text) =>
          parseMarkdown(text, {
            shouldReservePosition: true,
          }),
        ),
    );
    const definitionMap$ = Computed.fromObservables(
      [asts$],
      ([asts]): Readonly<Record<string, Definition>> => {
        const definitionMap: Record<string, Definition> = {
          ...presetDefinitionMap,
        };
        for (const ast of asts) {
          const map: Readonly<Record<string, Definition>> =
            calcDefinitionMap(ast).definitionMap;
          for (const [key, val] of Object.entries(map))
            definitionMap[key] = val;
        }
        return definitionMap;
      },
    );

    this.texts$ = texts$;
    this.asts$ = asts$;
    this.definitionMap$ = definitionMap$;
    this.rendererMap$ = new State(rendererMap);
    this.showCodeLineno$ = new State<boolean>(showCodeLineno);
    this.themeScheme$ = new State<IReactMarkdownThemeScheme>(themeScheme);
  }

  public setContent = (texts: string[]): void => {
    this.texts$.next(texts);
  };

  public getFullText = (): string => {
    const texts: string[] = this.texts$.getSnapshot();
    return texts.join('\n\n');
  };
}
