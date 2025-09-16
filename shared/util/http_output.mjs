import fs from "node:fs/promises";
import { formatHeaders, formatRequestBody, formatResponseBody } from "./http_response.mjs";

/**
 * @param {Response} response
 * @param {string} responseText
 * @param {Object} parsedRequest
 * @param {string} outputPath
 * @returns {Promise<void>}
 */
export async function writeHttpOutput(response, responseText, parsedRequest, outputPath) {
  const output = {
    status: response.status,
    statusText: response.statusText,
    headers: Object.fromEntries(response.headers.entries()),
    body: responseText,
  };

  const formattedResponseBody = formatResponseBody(response, responseText);
  const responseHeaders = formatHeaders(output.headers);
  const requestHeaders = formatHeaders(parsedRequest.headers);
  const requestBody = formatRequestBody(parsedRequest.body);

  const outputContent = `### Request ###
${parsedRequest.method.toUpperCase()} ${parsedRequest.url}

Request Headers:
${requestHeaders || "None"}

Request Body:
${requestBody || "None"}

### Response ###
HTTP/${response.status} ${response.statusText}

Response Headers:
${responseHeaders}

Response Body:
${formattedResponseBody}`;

  await fs.writeFile(outputPath, outputContent, "utf8");
}

/**
 * @param {Error} error
 * @param {string} outputPath
 * @returns {Promise<void>}
 */
export async function writeErrorOutput(error, outputPath) {
  const errorContent = `ERROR: ${error.message}\nTimestamp: ${new Date().toISOString()}`;
  await fs.writeFile(outputPath, errorContent, "utf8");
}