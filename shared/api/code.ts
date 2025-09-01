import { ApiRoutePathEnum } from '../constant/api'
import { requester } from './requester'

export class CodeController {
  public async listDefaults(filetype: string): Promise<string> {
    const response = await requester.get(
      `${ApiRoutePathEnum.CODE_DEFAULTS}/${encodeURIComponent(filetype.trim())}`,
    )

    if (!response.ok) {
      if (response.status === 404) {
        throw new Error('Default template not found for this file type')
      }

      const errorData = await response.json().catch(() => null)
      const errorMessage =
        errorData?.error ||
        `Failed to fetch default code: ${response.status} ${response.statusText}`
      throw new Error(errorMessage)
    }

    return response.text()
  }
}

export const codeController = new CodeController()
