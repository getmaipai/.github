// GENERATED FILE. Do not edit by hand.
// Source: standards/schemas/trace-span.schema.json
// Regenerate with: cd standards && bun run gen:ts

import { z } from "zod";

/**One span in a trace. One trace id runs from wake word through the router, a package, and an integration to the reply, shown as a timeline in Developer tools. See platform plan 2.1 and docs/ENGINEERING.md > Debugging and diagnostics.*/
export const TraceSpan = z
  .object({
    trace_id: z.string().min(1),
    span_id: z.string().min(1),
    parent_span_id: z.union([z.string(), z.null()]).default(null),
    /**e.g. wakeword.detect, router.route, skill.handle:bedtime-reminder, integration.call:home_assistant.*/
    name: z
      .string()
      .describe(
        "e.g. wakeword.detect, router.route, skill.handle:bedtime-reminder, integration.call:home_assistant.",
      ),
    /**Which node emitted this span. A cross-node call (5.3) gets a span on each side sharing the trace_id.*/
    node: z
      .enum(["home", "bot"])
      .describe(
        "Which node emitted this span. A cross-node call (5.3) gets a span on each side sharing the trace_id.",
      ),
    start: z.string().datetime({ offset: true }),
    /**Null while the span is still open.*/
    end: z
      .union([
        z
          .string()
          .datetime({ offset: true })
          .describe("Null while the span is still open."),
        z.null().describe("Null while the span is still open."),
      ])
      .describe("Null while the span is still open.")
      .default(null),
    status: z.enum(["ok", "error"]).default("ok"),
    attributes: z.record(z.string(), z.any()).default({}),
  })
  .strict()
  .describe(
    "One span in a trace. One trace id runs from wake word through the router, a package, and an integration to the reply, shown as a timeline in Developer tools. See platform plan 2.1 and docs/ENGINEERING.md > Debugging and diagnostics.",
  );
export type TraceSpan = z.infer<typeof TraceSpan>;
