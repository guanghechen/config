import fs from "node:fs/promises";
import { formatHeaders, formatRequestBody } from "../util/http_response.mjs";

/**
 * @param {Response} response
 * @param {string} responsePath
 * @param {Object} parsedRequest
 * @returns {Promise<string>}
 */
export async function handleSseResponse(response, responsePath, parsedRequest) {
  const responseHeaders = formatHeaders(Object.fromEntries(response.headers.entries()));

  let initialContent = `${parsedRequest.method.toUpperCase()} ${parsedRequest.url} HTTP/1.1`;

  if (responseHeaders) {
    initialContent += `\n${responseHeaders}`;
  }

  initialContent += "\n\n";

  await fs.writeFile(responsePath, initialContent, "utf8");
  console.log(`SSE response streaming to: ${responsePath}`);

  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let accumulatedBody = "";

  try {
    while (true) {
      const { done, value } = await reader.read();

      if (done) {
        break;
      }

      const chunk = decoder.decode(value, { stream: true });
      accumulatedBody += chunk;

      await fs.appendFile(responsePath, chunk, "utf8");
      process.stdout.write(chunk);
    }
  } finally {
    reader.releaseLock();
  }

  console.log(`\nSSE stream completed. Full response saved to: ${responsePath}`);
  return accumulatedBody;
}