import { ApiRoutePathEnum } from '../constant/api'
import type {
  IFetchFileData,
  IFetchFileResult,
  IFileSaveRequestPayload,
  IHtmlFileData,
  ISvgFileData,
  ITextFileData,
} from '../types/api'
import { requester } from './requester'

export class FileController {
  public async resolve<T extends IFetchFileData = IFetchFileData>(
    workspace: string | null,
    filepath: string,
  ): Promise<IFetchFileResult<T>> {
    if (!filepath) return {}

    try {
      const query: Record<string, string> = { filepath }
      const params = new URLSearchParams(query)
      if (workspace) params.set('workspace', workspace)

      const url = `${ApiRoutePathEnum.FILE}?${params}`
      const response = await requester.get(url)

      const contentType = response.headers.get('content-type')

      if (contentType?.includes('application/json')) {
        const data = await response.json()
        return { error: data.error, data: data.data }
      }

      if (contentType?.includes('image/svg+xml')) {
        const content: string = await response.text()
        const data: ISvgFileData = { content }
        return { data: data as T }
      }

      if (contentType?.includes('text/html')) {
        const content: string = await response.text()
        const data: IHtmlFileData = { content }
        return { data: data as T }
      }

      if (contentType?.includes('text/plain')) {
        const content: string = await response.text()
        const data: ITextFileData = { content }
        return { data: data as T }
      }

      if (contentType?.includes('text')) {
        const text = await response.text()
        return { text }
      }

      if (contentType?.includes('application/pdf')) {
        const blob = await response.blob()
        const url = URL.createObjectURL(blob)
        return { url }
      }

      if (contentType?.includes('image') || contentType?.includes('video')) {
        const blob = await response.blob()
        const url = URL.createObjectURL(blob)
        return { url }
      }
      return { error: `Unknown content type: ${contentType}` }
    } catch (error) {
      console.error('Failed to fetching file:', { workspace, filepath, error })

      // Handle authentication errors gracefully
      if (error instanceof Error && error.message === 'Authentication required') {
        return { error: 'Authentication required' }
      }

      return { error: 'Failed to fetching file: ' + JSON.stringify({ workspace, filepath, error }) }
    }
  }

  public async save(params: IFileSaveRequestPayload): Promise<void> {
    const { workspace, filepath, content } = params

    const response = await requester.post(ApiRoutePathEnum.FILE_SAVE, {
      workspace,
      filepath,
      content,
    })

    if (!response.ok) {
      throw new Error(`Failed to save: ${response.status} ${response.statusText}`)
    }
  }
}

export const fileController = new FileController()
