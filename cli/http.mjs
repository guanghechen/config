import fs from "node:fs/promises";
import path from "node:path";
import { v4 } from "uuid";
import {
  envParser,
  formatResponseBody,
  formatRequestBody,
  formatHeaders,
  git,
  httpParser,
} from "#shared";

const regexes = {
  splitter: /\n[-]{100}\n/,
  template: /\{\{\s*(\w+(?:\(\))?)\s*\}\}/g,
};

/**
 * @param {Object} parsedRequest
 * @returns {Promise<Response>}
 */
async function makeHttpRequest(parsedRequest) {
  const { method, url, headers, body } = parsedRequest;

  const fetchOptions = {
    method: method.toUpperCase(),
    headers: { ...headers },
  };

  if (
    body &&
    method.toUpperCase() !== "GET" &&
    method.toUpperCase() !== "HEAD"
  ) {
    if (body.type === "json") {
      fetchOptions.body = JSON.stringify(body.data);
      if (!fetchOptions.headers["Content-Type"]) {
        fetchOptions.headers["Content-Type"] = "application/json";
      }
    } else if (body.type === "form") {
      const formData = new URLSearchParams();
      for (const [key, value] of Object.entries(body.fields)) {
        formData.append(key, value);
      }
      fetchOptions.body = formData;
    } else if (body.type === "text") {
      fetchOptions.body = body.data;
    } else if (body.type === "file") {
      const fileContent = await fs.readFile(body.filepath);
      fetchOptions.body = fileContent;
    }
  }

  return fetch(url, fetchOptions);
}

/**
 * @param {string} filepath
 * @returns {Promise<Record<string, unknown>>}
 */
async function loadEnv(filepath) {
  let env = { ...process.env };

  const to = path.dirname(filepath);
  const gitRepoRootDir = git.resolveGitRepoRootDir(to);
  const from = gitRepoRootDir || to;

  await envParser.loads(from, to, env);
  return env;
}

/**
 * @param {string} filepath
 * @returns {Promise<void>}
 */
async function run(filepath) {
  const outputPath = filepath + ".out";
  const httpContent = await fs.readFile(filepath, "utf8");
  const parts = httpContent.split(regexes.splitter);

  let httpText = httpContent;
  let env = await loadEnv(filepath);

  if (parts.length === 1) {
    httpText = parts[0];
  } else if (parts.length === 2) {
    const [envText, requestText] = parts;
    httpText = requestText;

    if (envText.trim()) {
      const parsed = envParser.parse(envText);
      env = { ...env, ...parsed };
    }
  }

  const processedHttpText = httpText
    .trim()
    .replace(regexes.template, (match, key) => {
      if (key === "uuid()" || key === "uuidv4()") return v4();
      return env[key] || match;
    });
  const parsedRequest = httpParser.parse(processedHttpText);

  console.log("Making request to:", parsedRequest.url);
  console.log("Method:", parsedRequest.method);

  try {
    const response = await makeHttpRequest(parsedRequest);
    const responseText = await response.text();

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

    console.log(`Response saved to: ${outputPath}`);
    console.log(`Status: ${response.status} ${response.statusText}`);
  } catch (error) {
    console.error("Request failed:", error.message);

    const errorContent = `ERROR: ${error.message}\nTimestamp: ${new Date().toISOString()}`;
    await fs.writeFile(outputPath, errorContent, "utf8");
    console.log(`Error saved to: ${outputPath}`);
  }
}

const httpFilepath = process.argv[2];
if (!httpFilepath) {
  console.error("Usage: node http.mjs <http-file-path>");
  process.exit(1);
}

const resolvedPath = path.isAbsolute(httpFilepath)
  ? httpFilepath
  : path.resolve(process.cwd(), httpFilepath);

await run(resolvedPath);
