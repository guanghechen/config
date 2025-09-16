import fs from "node:fs/promises";

/**
 * @param {Object} parsedRequest
 * @returns {Promise<Response>}
 */
export async function makeHttpRequest(parsedRequest) {
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
 * @param {Response} response
 * @returns {boolean}
 */
export function isServerSentEvent(response) {
  const contentType = response.headers.get('content-type');
  return contentType && contentType.includes('text/event-stream');
}