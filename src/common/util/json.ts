import JSON5 from 'json5'

export interface IJsonParseResult {
  readonly isValid: boolean
  readonly isJsonl: boolean
  readonly parsedData?: unknown
  readonly error?: string
}

/**
 * Parse JSON or JSONL content with proper error handling
 * @param content - The string content to parse
 * @returns IJsonParseResult with parsing status and data
 */
export function parseJsonContent(content: string): IJsonParseResult {
  if (!content || typeof content !== 'string') {
    return {
      isValid: false,
      isJsonl: false,
      error: 'Content is empty or not a string',
    }
  }

  const trimmedContent = content.trim()
  if (!trimmedContent) {
    return {
      isValid: false,
      isJsonl: false,
      error: 'Content is empty after trimming',
    }
  }

  // Try parsing as regular JSON first using JSON5 for better compatibility
  try {
    const parsedJson = JSON5.parse(trimmedContent)
    return {
      isValid: true,
      isJsonl: false,
      parsedData: parsedJson,
    }
  } catch (jsonError) {
    // If JSON parsing fails, try parsing as JSONL
    try {
      const lines = trimmedContent.split('\n').filter(line => line.trim())
      const parsedLines: unknown[] = []

      for (const line of lines) {
        const trimmedLine = line.trim()
        if (trimmedLine) {
          const parsedLine = JSON5.parse(trimmedLine)
          parsedLines.push(parsedLine)
        }
      }

      if (parsedLines.length === 0) {
        return {
          isValid: false,
          isJsonl: false,
          error: 'No valid JSON objects found',
        }
      }

      return {
        isValid: true,
        isJsonl: true,
        parsedData: parsedLines,
      }
    } catch (jsonlError) {
      return {
        isValid: false,
        isJsonl: false,
        error: `Failed to parse as JSON or JSONL: ${jsonError instanceof Error ? jsonError.message : String(jsonError)}`,
      }
    }
  }
}

/**
 * Validate if content is valid JSON or JSONL
 * @param content - The string content to validate
 * @returns boolean indicating if content is valid
 */
export function isValidJsonContent(content: string): boolean {
  return parseJsonContent(content).isValid
}
