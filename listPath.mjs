import fs from "node:fs/promises";
import yaml from "yaml";

const filePath = "./openapi.yaml";

try {
  const content = await fs.readFile(filePath, "utf8");
  const openapi = yaml.parse(content);

  if (!openapi.paths) {
    console.error("Aucun path trouvé dans openapi.yaml");
    process.exit(1);
  }

  for (const [path, methods] of Object.entries(openapi.paths)) {
    console.log(`\n${path}`);

    for (const [method, operation] of Object.entries(methods)) {
      if (!["get", "post", "put", "patch", "delete", "options", "head", "trace"].includes(method)) {
        continue;
      }

      console.log(`  ${method.toUpperCase()} → ${operation.summary ?? "(sans summary)"}`);
    }
  }
} catch (error) {
  console.error("Erreur :", error.message);
  process.exit(1);
}