// GENERATED FILE. Do not edit by hand.
// Source: standards/schemas/logging-line.schema.json
// Regenerate with: cd standards && bun run gen:ts

import { z } from "zod";

/**One structured JSON log line. Packages log only through host.log, which stamps and redacts before a line ever reaches this shape; a raw log call never bypasses it. See platform plan 2.1 and docs/ENGINEERING.md > Logging.*/
export const LoggingLine = z
  .object({
    level: z.enum(["debug", "info", "warn", "error"]),
    timestamp: z.string().datetime({ offset: true }),
    /**The package that logged this line, or null for a core-emitted line.*/
    package_id: z
      .union([
        z
          .string()
          .describe(
            "The package that logged this line, or null for a core-emitted line.",
          ),
        z
          .null()
          .describe(
            "The package that logged this line, or null for a core-emitted line.",
          ),
      ])
      .describe(
        "The package that logged this line, or null for a core-emitted line.",
      )
      .default(null),
    /**The turn or op context this line belongs to, for the Developer tools timeline.*/
    context: z
      .object({ turn_id: z.string().optional(), op: z.string().optional() })
      .strict()
      .describe(
        "The turn or op context this line belongs to, for the Developer tools timeline.",
      )
      .optional(),
    /**Redacted by host.log before this line exists; never a secret, token, PII value, or transcript.*/
    message: z
      .string()
      .describe(
        "Redacted by host.log before this line exists; never a secret, token, PII value, or transcript.",
      ),
    /**Structured extras, also redacted by host.log.*/
    fields: z
      .record(z.string(), z.any())
      .describe("Structured extras, also redacted by host.log.")
      .default({}),
  })
  .strict()
  .describe(
    "One structured JSON log line. Packages log only through host.log, which stamps and redacts before a line ever reaches this shape; a raw log call never bypasses it. See platform plan 2.1 and docs/ENGINEERING.md > Logging.",
  );
export type LoggingLine = z.infer<typeof LoggingLine>;
