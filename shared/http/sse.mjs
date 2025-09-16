import fs from "node:fs/promises";
import { formatHeaders, formatRequestBody } from "../util/http_response.mjs";

/**
 * @param {Response} response
 * @param {string} outputPath
 * @param {Object} parsedRequest
 * @returns {Promise<string>}
 */
export async function handleSseResponse(response, outputPath, parsedRequest) {
  const requestHeaders = formatHeaders(parsedRequest.headers);
  const requestBody = formatRequestBody(parsedRequest.body);
  const responseHeaders = formatHeaders(Object.fromEntries(response.headers.entries()));

  const initialContent = `### Request ###
${parsedRequest.method.toUpperCase()} ${parsedRequest.url}

Request Headers:
${requestHeaders || "None"}

Request Body:
${requestBody || "None"}

### Response ###
HTTP/${response.status} ${response.statusText}

Response Headers:
${responseHeaders}

Response Body (SSE Stream):
`;

  await fs.writeFile(outputPath, initialContent, "utf8");
  console.log(`SSE response streaming to: ${outputPath}`);

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

      await fs.appendFile(outputPath, chunk, "utf8");
      process.stdout.write(chunk);
    }
  } finally {
    reader.releaseLock();
  }

  console.log(`\nSSE stream completed. Full response saved to: ${outputPath}`);
  return accumulatedBody;
}