import { existsSync } from 'node:fs'
import fs from 'node:fs/promises'
import path from 'node:path'
import { ROOT_DIR } from '../../../../../../../env'
import type { IApiHandle, IApiHandleData } from '../../../../types'

const TRANSFORMER_DATA_DIR = path.join(ROOT_DIR, 'server/plugin/api/d/transformer/text')

export const listTextTransformers: IApiHandle = async params => {
  const { pathname } = params

  try {
    if (!existsSync(TRANSFORMER_DATA_DIR)) {
      const data: IApiHandleData = {
        error: 'Transformer data directory not found',
        details: { pathname, transformerDataDir: TRANSFORMER_DATA_DIR },
        data: null,
      }
      return { code: 404, data }
    }

    // Read all JSON files in the transformer directory
    const files = await fs.readdir(TRANSFORMER_DATA_DIR)
    const jsonFiles = files.filter(file => file.endsWith('.json'))

    const transformers = []
    for (const file of jsonFiles) {
      try {
        const filepath = path.join(TRANSFORMER_DATA_DIR, file)
        const content = await fs.readFile(filepath, 'utf8')
        const transformer = JSON.parse(content)

        // Extract basic info for the list view
        transformers.push({
          name: transformer.name || path.basename(file, '.json'),
          description: transformer.description || null,
        })
      } catch (error) {
        // Skip invalid JSON files
        console.warn(`Skipping invalid transformer file: ${file}`, error)
      }
    }

    const data: IApiHandleData = {
      data: {
        transformers,
      },
    }
    return { code: 200, data }
  } catch (error) {
    const data: IApiHandleData = {
      error: 'Failed to list text transformers',
      details: { pathname, error: error instanceof Error ? error.message : 'Unknown error' },
      data: null,
    }
    return { code: 500, data }
  }
}
