// GENERATED FILE. Do not edit by hand.
// Source: standards/schemas/privacy-row.schema.json
// Regenerate with: cd standards && bun run gen:ts

import { z } from "zod";

/**One row of a 'what leaves the house' table: one outbound connection a package declares in its manifest's data_sources[]. The generated privacy page (docs/ENGINEERING.md > Privacy, CLAUDE.md > Privacy architecture) is built entirely from these declarations, never hand-maintained.*/
export const PrivacyRow = z
  .object({
    id: z.string().min(1),
    /**The host or service this connects to, named descriptively (docs/PACKAGES.md, the org's Trademarks rule).*/
    destination: z
      .string()
      .describe(
        "The host or service this connects to, named descriptively (docs/PACKAGES.md, the org's Trademarks rule).",
      ),
    /**The trigger, in plain language: 'on package install', 'each time the family asks for weather', 'once a day at the update check'.*/
    when: z
      .string()
      .describe(
        "The trigger, in plain language: 'on package install', 'each time the family asks for weather', 'once a day at the update check'.",
      ),
    /**What this connection carries, in plain language.*/
    what: z
      .string()
      .describe("What this connection carries, in plain language."),
    /**Who receives it: the named third-party service, or 'nobody, this stays on the LAN'.*/
    who: z
      .string()
      .describe(
        "Who receives it: the named third-party service, or 'nobody, this stays on the LAN'.",
      ),
    /**False only for the handful of core, always-on connections (update checks, the store's signed index); every integration is opt_in: true.*/
    opt_in: z
      .boolean()
      .describe(
        "False only for the handful of core, always-on connections (update checks, the store's signed index); every integration is opt_in: true.",
      ),
    /**How long the destination keeps it, in plain language, or 'unknown, see the service's own policy' when the household does not control it.*/
    retention: z
      .string()
      .describe(
        "How long the destination keeps it, in plain language, or 'unknown, see the service's own policy' when the household does not control it.",
      ),
  })
  .strict()
  .describe(
    "One row of a 'what leaves the house' table: one outbound connection a package declares in its manifest's data_sources[]. The generated privacy page (docs/ENGINEERING.md > Privacy, CLAUDE.md > Privacy architecture) is built entirely from these declarations, never hand-maintained.",
  );
export type PrivacyRow = z.infer<typeof PrivacyRow>;
