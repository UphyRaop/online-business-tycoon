import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import { createServer } from "node:http";
import { extname } from "node:path";

const root = new URL("../web-build/", import.meta.url);
const host = process.argv.includes("--lan") ? "0.0.0.0" : "127.0.0.1";
const port = 8060;
const mime = new Map([
  [".html", "text/html; charset=utf-8"],
  [".js", "text/javascript; charset=utf-8"],
  [".wasm", "application/wasm"],
  [".pck", "application/octet-stream"],
  [".png", "image/png"],
  [".ico", "image/x-icon"],
]);

await stat(new URL("index.html", root)).catch(() => {
  throw new Error("Export the Godot Web preset to web-build/index.html first.");
});

createServer(async (request, response) => {
  const pathname = new URL(request.url, "http://localhost").pathname;
  const name = pathname === "/" ? "index.html" : pathname.slice(1);
  const type = mime.get(extname(name));
  // Serve the flat export folder only.
  if (!/^index(?:\.[\w-]+)+$/.test(name) || !type) {
    response.writeHead(404).end();
    return;
  }

  const file = new URL(name, root);
  try {
    const { size } = await stat(file);
    response.writeHead(200, {
      "Content-Type": type,
      "Content-Length": size,
      "Cache-Control": "no-cache",
    });
    if (request.method === "HEAD") {
      response.end();
      return;
    }
    createReadStream(file).on("error", () => response.destroy()).pipe(response);
  } catch {
    response.writeHead(404).end();
  }
}).listen(port, host, () => {
  console.log(`Online Business Tycoon is running at http://localhost:${port}/`);
  if (host === "0.0.0.0") {
    console.log(`On your iPhone, open http://<Windows IPv4 address>:${port}/ on the same Wi-Fi.`);
  }
});
