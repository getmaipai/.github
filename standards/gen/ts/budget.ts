// GENERATED FILE. Do not edit by hand.
// Source: standards/schemas/budget.schema.json
// Regenerate with: cd standards && bun run gen:ts

import { z } from "zod";

/**One performance budget declaration, measured against a named reference machine. See platform plan 2.2 > Performance budgets. CI measures against these; the release skill re-runs the benches; the host faults a package that runs over its own timeout_ms budget at runtime (that check uses the package manifest's timeout_ms directly, not this file, which is for the budgets CI proves in aggregate: prompt assembly, page-open, cold shell, and similar).*/
export const Budget = z
  .object({
    id: z.string().regex(new RegExp("^[a-z][a-z0-9_]*$")),
    description: z.string().optional(),
    /**What this budget bounds, e.g. first_token_ms, cold_shell_ms, page_open_ms, prompt_tokens, handle_timeout_ms, memory_mb.*/
    metric: z
      .string()
      .describe(
        "What this budget bounds, e.g. first_token_ms, cold_shell_ms, page_open_ms, prompt_tokens, handle_timeout_ms, memory_mb.",
      ),
    threshold: z.number(),
    unit: z.enum(["ms", "tokens", "mb"]),
    /**The named reference machines from 2.2: the MSI hub, a two-generation-old laptop, a two-generation-old iPhone, the current Apple TV, the bench Pi.*/
    reference_machine: z
      .enum([
        "msi_hub",
        "two_gen_laptop",
        "two_gen_iphone",
        "current_apple_tv",
        "bench_pi",
      ])
      .describe(
        "The named reference machines from 2.2: the MSI hub, a two-generation-old laptop, a two-generation-old iPhone, the current Apple TV, the bench Pi.",
      ),
  })
  .strict()
  .describe(
    "One performance budget declaration, measured against a named reference machine. See platform plan 2.2 > Performance budgets. CI measures against these; the release skill re-runs the benches; the host faults a package that runs over its own timeout_ms budget at runtime (that check uses the package manifest's timeout_ms directly, not this file, which is for the budgets CI proves in aggregate: prompt assembly, page-open, cold shell, and similar).",
  );
export type Budget = z.infer<typeof Budget>;
