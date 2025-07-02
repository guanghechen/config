import type { Html } from '@yozora/ast'
import React from 'react'
import sanitizeHtml from 'sanitize-html'

/**
 * Validates if the given string is valid HTML
 */
function isValidHtml(htmlString: string): boolean {
  try {
    // Create a temporary DOM element to test parsing
    const parser = new DOMParser()
    const doc = parser.parseFromString(htmlString, 'text/html')

    // Check for parser errors
    const errorElement = doc.querySelector('parsererror')
    if (errorElement) {
      return false
    }

    // Additional check: if the content is empty or just whitespace after parsing
    const body = doc.body
    if (!body || (!body.textContent?.trim() && body.children.length === 0)) {
      return false
    }

    return true
  } catch {
    return false
  }
}

/**
 * Render `html` as text with styling to indicate it's HTML content.
 * If the HTML is invalid, render it as code with error styling.
 *
 * @see https://www.npmjs.com/package/@yozora/ast#html
 * @see https://www.npmjs.com/package/@yozora/tokenizer-html
 */
export class HtmlRenderer extends React.Component<Html> {
  public override shouldComponentUpdate(nextProperties: Readonly<Html>): boolean {
    const properties = this.props
    return properties.value !== nextProperties.value
  }

  public override render(): React.ReactElement {
    const { value } = this.props
    const sanitizedValue = sanitizeHtml(value)

    // Check if the original value is valid HTML
    if (!isValidHtml(value)) {
      // Render invalid HTML as code with error styling
      return (
        <div className="yozora-html">
          <div
            style={{
              border: '1px solid #ff6b6b',
              borderRadius: '4px',
              backgroundColor: '#fff5f5',
              padding: '8px',
              margin: '4px 0',
            }}
          >
            <div
              style={{
                color: '#c92a2a',
                fontSize: '12px',
                fontWeight: 'bold',
                marginBottom: '4px',
              }}
            >
              Invalid HTML Content:
            </div>
            <pre
              className="yozora-html-code"
              style={{
                fontFamily: 'var(--fontFamilyCode)',
                backgroundColor: 'var(--colorBgCode)',
                padding: '8px',
                borderRadius: '4px',
                overflow: 'auto',
                margin: 0,
                whiteSpace: 'pre-wrap',
                wordBreak: 'break-word',
              }}
            >
              <code>{value}</code>
            </pre>
          </div>
        </div>
      )
    }

    // Render valid HTML normally
    return (
      <div className="yozora-html">
        <div dangerouslySetInnerHTML={{ __html: sanitizedValue }} />
      </div>
    )
  }
}
