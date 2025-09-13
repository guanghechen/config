const regexes = {
  line: /^(\w+)\s+(.+?)(?:\s+(HTTP\/[\d.]+))?\s*$/,
  header: /^([^:]+):\s*(.*)$/,
  file: /@file\.(.+)$/,
  lf: /\n+/g,
  formField: /^([^=]+)=(.*)$/,
  boundary: /boundary=([^;\s]+)/i,
};

function parseLine(line) {
  const match = regexes.line.exec(line);

  if (!match) {
    throw new Error("Invalid HTTP request line");
  }

  const [, method, url, protocol = "HTTP/1.1"] = match;
  return { method, url, protocol };
}

function parseHeaders(text) {
  const headers = {};
  const lines = text.trim().split(regexes.lf);

  for (const line of lines) {
    const trimmedLine = line.trim();
    if (!trimmedLine) continue;

    const match = regexes.header.exec(trimmedLine);
    if (match) {
      const [, name, value] = match;
      headers[name.trim()] = value.trim();
    }
  }

  return headers;
}

function parseBody(text, headers = {}) {
  const trimmedText = text.trim();
  if (!trimmedText) return null;

  const contentType = headers["Content-Type"] || headers["content-type"] || "";

  // Handle multipart/form-data
  if (contentType.includes("multipart/form-data")) {
    const boundaryMatch = regexes.boundary.exec(contentType);
    if (boundaryMatch) {
      return parseMultipartFormData(trimmedText, boundaryMatch[1]);
    }
  }

  // Handle application/x-www-form-urlencoded
  if (contentType.includes("application/x-www-form-urlencoded")) {
    return parseFormUrlEncoded(trimmedText);
  }

  // Check if it's a file reference
  const fileMatch = regexes.file.exec(trimmedText);
  if (fileMatch) {
    return {
      type: "file",
      filepath: fileMatch[1],
    };
  }

  // Handle JSON
  if (
    contentType.includes("application/json") ||
    trimmedText.startsWith("{") ||
    trimmedText.startsWith("[")
  ) {
    try {
      const parsed = JSON.parse(trimmedText);
      return {
        type: "json",
        data: parsed,
      };
    } catch {
      // Fall through to text if JSON parsing fails
    }
  }

  // Default to text
  return {
    type: "text",
    data: trimmedText,
  };
}

function parseMultipartFormData(text, boundary) {
  const parts = text
    .split(`--${boundary}`)
    .filter((part) => part.trim() && !part.trim().startsWith("--"));
  const fields = {};
  const files = [];

  for (const part of parts) {
    const [headerSection, ...bodyParts] = part.split("\n\n");
    const body = bodyParts.join("\n\n").trim();
    const headers = parseHeaders(headerSection);

    const disposition =
      headers["Content-Disposition"] || headers["content-disposition"] || "";
    const nameMatch = /name="([^"]+)"/.exec(disposition);
    const filenameMatch = /filename="([^"]+)"/.exec(disposition);

    if (nameMatch) {
      const name = nameMatch[1];

      if (filenameMatch) {
        // File field
        const fileMatch = regexes.file.exec(body);
        files.push({
          name,
          filename: filenameMatch[1],
          filepath: fileMatch ? fileMatch[1] : null,
          data: fileMatch ? null : body,
          contentType:
            headers["Content-Type"] ||
            headers["content-type"] ||
            "application/octet-stream",
        });
      } else {
        // Regular field
        fields[name] = body;
      }
    }
  }

  return {
    type: "formdata",
    fields,
    files,
  };
}

function parseFormUrlEncoded(text) {
  const fields = {};
  const pairs = text.split("&");

  for (const pair of pairs) {
    const match = regexes.formField.exec(pair);
    if (match) {
      const [, key, value] = match;
      fields[decodeURIComponent(key)] = decodeURIComponent(value);
    }
  }

  return {
    type: "form",
    fields,
  };
}

function parse(text) {
  const sections = text.trim().split("\n\n");
  if (sections.length === 0) {
    throw new Error("Empty HTTP request");
  }

  // Parse the first section (request line + headers)
  const firstSection = sections[0];
  const lines = firstSection.split("\n");
  const requestLine = lines[0];
  const headerLines = lines.slice(1);

  // Parse request line
  const { method, url, protocol } = parseLine(requestLine);

  // Parse headers
  const headers = parseHeaders(headerLines.join("\n"));

  // Parse body if present
  let body = null;
  if (sections.length > 1) {
    const bodyText = sections.slice(1).join("\n\n");
    body = parseBody(bodyText, headers);
  }

  return {
    method,
    url,
    protocol,
    headers,
    body,
  };
}

export const httpParser = {
  parse,
  parseLine,
  parseHeaders,
  parseBody,
};
