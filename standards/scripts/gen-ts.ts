// Generates standards/gen/ts/*.ts from standards/schemas/*.schema.json.
// Committed output, not run at build time. Run with: bun run gen:ts (from
// standards/), then commit the result. Mirrors home/spec/scripts/gen-ts.ts;
// no cross-file $refs here yet, so no $id resolver override is needed.
import { readdir, mkdir, writeFile, rm } from "node:fs/promises";
import { join, basename } from "node:path";
import $RefParser from "@apidevtools/json-schema-ref-parser";
import { jsonSchemaToZod } from "json-schema-to-zod";
import prettier from "prettier";

const SCHEMAS_DIR = join(import.meta.dir, "..", "schemas");
const OUT_DIR = join(import.meta.dir, "..", "gen", "ts");

async function main() {
  await rm(OUT_DIR, { recursive: true, force: true });
  await mkdir(OUT_DIR, { recursive: true });

  const files = (await readdir(SCHEMAS_DIR)).filter((f) => f.endsWith(".schema.json"));
  const generated: { fileBase: string; typeName: string }[] = [];

  for (const file of files) {
    const path = join(SCHEMAS_DIR, file);
    const dereferenced = await $RefParser.dereference(path);
    const fileBase = basename(file, ".schema.json");
    const title = (dereferenced as { title?: string }).title;
    const typeName = title ? title.replace(/[^a-zA-Z0-9]/g, "") : fileBase;

    const code = jsonSchemaToZod(dereferenced as Record<string, unknown>, {
      name: typeName,
      module: "esm",
      type: true,
      withJsdocs: true,
      zodVersion: 4,
    });

    const header = `// GENERATED FILE. Do not edit by hand.\n// Source: standards/schemas/${file}\n// Regenerate with: cd standards && bun run gen:ts\n\n`;
    const formatted = await prettier.format(header + code + "\n", { parser: "typescript" });
    await writeFile(join(OUT_DIR, `${fileBase}.ts`), formatted);
    generated.push({ fileBase, typeName });
  }

  const indexLines = [
    "// GENERATED FILE. Do not edit by hand.",
    "// Regenerate with: cd standards && bun run gen:ts",
    "",
    ...generated.map((g) => `export * from "./${g.fileBase}.js";`),
    "",
  ];
  await writeFile(join(OUT_DIR, "index.ts"), indexLines.join("\n"));

  console.log(`Generated ${generated.length} schema module(s) into standards/gen/ts/.`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
