import fs from "node:fs/promises";
import { formatHeaders, formatRequestBody, formatResponseBody } from "./http_response.mjs";

/**
 * @param {Object} parsedRequest
 * @param {string} requestPath
 * @returns {Promise<void>}
 */
export async function writeHttpRequest(parsedRequest, requestPath) {
  const requestHeaders = formatHeaders(parsedRequest.headers);
  const requestBody = formatRequestBody(parsedRequest.body);

  let content = `${parsedRequest.method.toUpperCase()} ${parsedRequest.url} HTTP/1.1`;

  if (requestHeaders) {
    content += `\n${requestHeaders}`;
  }

  if (requestBody) {
    content += `\n\n${requestBody}`;
  }

  await fs.writeFile(requestPath, content, "utf8");
}

/**
 * @param {Response} response
 * @param {string} responseText
 * @param {Object} parsedRequest
 * @param {string} responsePath
 * @returns {Promise<void>}
 */
export async function writeHttpResponse(response, responseText, parsedRequest, responsePath) {
  const formattedResponseBody = formatResponseBody(response, responseText);
  const responseHeaders = formatHeaders(Object.fromEntries(response.headers.entries()));

  let content = `${parsedRequest.method.toUpperCase()} ${parsedRequest.url} HTTP/1.1`;

  if (responseHeaders) {
    content += `\n${responseHeaders}`;
  }

  if (formattedResponseBody) {
    content += `\n\n${formattedResponseBody}`;
  }

  await fs.writeFile(responsePath, content, "utf8");
}

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
 * @param {string} responsePath
 * @returns {Promise<void>}
 */
export async function writeErrorOutput(error, responsePath) {
  const errorContent = `ERROR: ${error.message}\nTimestamp: ${new Date().toISOString()}`;
  await fs.writeFile(responsePath, errorContent, "utf8");
}