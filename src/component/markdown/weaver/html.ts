import type {
  Blockquote,
  Break,
  Code,
  Definition,
  Delete,
  Emphasis,
  Heading,
  Html,
  Image,
  ImageReference,
  InlineCode,
  InlineMath,
  Link,
  LinkReference,
  List,
  ListItem,
  Math,
  Paragraph,
  Root,
  Strong,
  Table,
  TableCell,
  Text,
  ThematicBreak,
} from '@yozora/ast'
import {
  BlockquoteType,
  BreakType,
  CodeType,
  DefinitionType,
  DeleteType,
  EmphasisType,
  HeadingType,
  HtmlType,
  ImageReferenceType,
  ImageType,
  InlineCodeType,
  InlineMathType,
  LinkReferenceType,
  LinkType,
  ListItemType,
  ListType,
  MathType,
  ParagraphType,
  StrongType,
  TableCellType,
  TableType,
  TextType,
  ThematicBreakType,
} from '@yozora/ast'
import { calcDefinitionMap } from '@yozora/ast-util'
import sanitizeHtml from 'sanitize-html'
import { parseMarkdown } from '../parser'
import type { InlineCitation } from '../parser/ast'
import { InlineCitationType } from '../parser/ast'

type INode =
  | Blockquote
  | Break
  | Definition
  | Delete
  | Emphasis
  | Code
  | Heading
  | Html
  | Image
  | ImageReference
  | InlineCitation
  | InlineCode
  | InlineMath
  | Link
  | LinkReference
  | List
  | ListItem
  | Math
  | Paragraph
  | Strong
  | Table
  | TableCell
  | Text
  | ThematicBreak

function escapeHtml(html: string): string {
  return html
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;')
}

export const convertToHtml = (content: string): string => {
  let ast: Root = parseMarkdown(content)
  const { definitionMap, root } = calcDefinitionMap(ast, [DefinitionType], undefined)
  ast = root

  return ast.children.map(node => nodeToHtml(node as INode)).join('\n\n')

  function nodeToHtml(node: INode): string {
    switch (node.type) {
      case BlockquoteType: {
        const text: string = node.children.map(o => nodeToHtml(o as INode)).join('\n')
        return `<blockquote>${text}</blockquote>`
      }
      case BreakType: {
        return '<br/>'
      }
      case CodeType: {
        const text: string = escapeHtml(node.value)
        if (node.lang) {
          return `<pre><code className="${escapeHtml(node.lang)}">${text}</pre></code>`
        }
        return `<pre><code>${text}</pre></code>`
      }
      case DefinitionType: {
        return ''
      }
      case DeleteType: {
        const text: string = node.children.map(o => nodeToHtml(o as INode)).join(' ')
        return `<del>${text}</del>`
      }
      case HeadingType: {
        const text: string = node.children.map(o => nodeToHtml(o as INode)).join(' ')
        const tag = 'h' + node.depth
        return `<${tag}>${text}</${tag}>`
      }
      case HtmlType: {
        const text: string = sanitizeHtml(node.value)
        return `<pre><code className="language-html">${text}</code></pre>`
      }
      case EmphasisType: {
        const text: string = node.children.map(o => nodeToHtml(o as INode)).join(' ')
        return `<em>${text}</em>`
      }
      case InlineCitationType: {
        return `<span data-inline-type="citation" data-citation-id="${node.code}" data-lexical-decorator="true"></span>`
      }
      case ImageType: {
        let result: string = `<img src="${escapeHtml(node.url)}"`
        if (node.alt) result += ` alt="${escapeHtml(node.alt)}"`
        if (node.title) result += ` title="${escapeHtml(node.title)}"`
        return result + ' />'
      }
      case ImageReferenceType: {
        const definition = definitionMap[node.identifier]
        if (!definition) return ''

        let result: string = `<img src="${escapeHtml(definition.url)}"`
        if (node.alt) result += ` alt="${escapeHtml(node.alt)}"`
        if (definition.title) result += ` title="${escapeHtml(definition.title)}"`
        return result + ' />'
      }
      case InlineCodeType: {
        const text: string = escapeHtml(node.value)
        return `<code>${text}</code>`
      }
      case InlineMathType: {
        const text: string = escapeHtml(node.value)
        return `<code>$${text}$</code>`
      }
      case LinkType: {
        const text: string = node.children.map(o => nodeToHtml(o as INode)).join(' ')
        let result: string = `<a href=${escapeHtml(node.url)}`
        if (node.title) result += ` title="${escapeHtml(node.title)}"`
        return result + `>${text}</a>`
      }
      case LinkReferenceType: {
        const definition = definitionMap[node.identifier]
        if (!definition) return ''

        const text: string = node.children.map(o => nodeToHtml(o as INode)).join(' ')
        let result: string = `<a href=${escapeHtml(definition.url)}`
        if (definition.title) result += ` title="${escapeHtml(definition.title)}"`
        return result + `>${text}</a>`
      }
      case ListType: {
        const text: string = node.children.map(o => nodeToHtml(o as INode)).join('\n')
        if (node.ordered) {
          let result: string = '<ol'
          if (Number(node.start) && Number(node.start) > 0)
            result += ` start="${Number(node.start)}"`
          return result + `>${text}</ol>`
        }
        return `<ul>${text}</ul>`
      }
      case ListItemType: {
        const text: string = node.children.map(o => nodeToHtml(o as INode)).join(' ')
        return `<li>${text}</li>`
      }
      case MathType: {
        const text: string = escapeHtml(node.value)
        return `<p>${text}</p>`
      }
      case ParagraphType: {
        const text: string = node.children.map(o => nodeToHtml(o as INode)).join('')
        return `<p>${text}</p>`
      }
      case StrongType: {
        const text: string = node.children.map(o => nodeToHtml(o as INode)).join(' ')
        return `<strong>${text}</strong>`
      }
      case TableType: {
        let result: string = '<table>\n<thead>\n<tr>'
        const [th, ...trs] = node.children
        for (let i = 0; i < node.columns.length; ++i) {
          const column = node.columns[i]
          const cell = th.children[i]

          if (cell) {
            result += '\n<th'
            if (column.align) result += ` align="${escapeHtml(column.align)}"`
            result += '>' + nodeToHtml(cell as INode) + '</th>\n'
          }
        }
        result += '\n</tr></thead>\n<tbody>'

        for (const tr of trs) {
          result += '\n<tr>'
          for (let i = 0; i < node.columns.length; ++i) {
            const column = node.columns[i]
            const cell = tr.children[i]
            result += '\n<td'
            if (column.align) result += ` align="${escapeHtml(column.align)}"`
            result += '>' + nodeToHtml(cell as INode) + '</td>\n'
          }
          result += '\n</tr>'
        }
        result += '\n</tbody>\n</table>'
        return result
      }
      case TableCellType: {
        const text: string = node.children.map(o => nodeToHtml(o as INode)).join(' ')
        return text
      }
      case TextType: {
        const text: string = escapeHtml(node.value)
        return text
      }
      case ThematicBreakType: {
        return '<hr/>'
      }
      default: {
        return JSON.stringify(node)
      }
    }
  }
}
