/**
 * Formats the response body based on content type
 * @param {Response} response - The fetch Response object
 * @param {string} responseText - The raw response text
 * @returns {string} - Formatted response body
 */
export function formatResponseBody(response, responseText) {
  let formattedResponseBody = responseText;
  const contentType = response.headers.get('content-type');

  if (contentType && contentType.includes('application/json') && responseText.trim()) {
    try {
      const jsonData = JSON.parse(responseText);
      formattedResponseBody = JSON.stringify(jsonData, null, 2);
    } catch (e) {
      // Keep original text if JSON parsing fails
    }
  }

  return formattedResponseBody;
}

/**
 * Formats request body for display
 * @param {Object} body - The parsed request body
 * @returns {string} - Formatted request body
 */
export function formatRequestBody(body) {
  if (!body) return '';

  if (body.type === 'json') {
    return JSON.stringify(body.data, null, 2);
  } else if (body.type === 'form') {
    return Object.entries(body.fields)
      .map(([key, value]) => `${key}=${value}`)
      .join('&');
  }

  return body.data || '';
}

/**
 * Formats headers for display
 * @param {Object} headers - Headers object
 * @returns {string} - Formatted headers
 */
export function formatHeaders(headers) {
  return Object.entries(headers || {})
    .map(([key, value]) => `${key}: ${value}`)
    .join('\n');
}