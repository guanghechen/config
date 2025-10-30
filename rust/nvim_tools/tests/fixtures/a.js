import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const filepathA = path.resolve(__dirname, "a.txt");
const filepathB = path.resolve(__dirname, "b.txt");
const filepathC = path.resolve(__dirname, "c.txt");

const f = (eol, rep = 5) => {
  return (
    ("Hello, world!" + eol).repeat(rep) +
    eol +
    eol +
    ("Hello, 世界!" + eol).repeat(rep)
  );
};

fs.writeFileSync(filepathA, f("\n"), "utf8");
fs.writeFileSync(filepathB, f("\r\n"), "utf8");
fs.writeFileSync(filepathC, f("\r"), "utf8");
