// GENERATED FILE. Do not edit by hand.
// Source: standards/schemas/error-entry.schema.json
// Regenerate with: cd standards && bun run gen:ts

import { z } from "zod";

/**The shape of one code in an error catalogue. Every package error the host wraps maps to one of these. home/spec/errors/errors.json is the populated catalogue for the platform; this is the shape it (and any other repo's catalogue) conforms to. See platform plan 2.1, 4.9, and docs/ENGINEERING.md > Errors.*/
export const ErrorEntry = z
  .object({
    code: z.string().regex(new RegExp("^[a-z][a-z0-9_]*$")),
    /**Developer-facing, goes in logs and diagnostics.*/
    message: z
      .string()
      .describe("Developer-facing, goes in logs and diagnostics."),
    /**What the robot or a voice surface says when this error surfaces mid-conversation.*/
    spoken_fallback: z
      .string()
      .describe(
        "What the robot or a voice surface says when this error surfaces mid-conversation.",
      ),
    /**What the shell shows: specific title, what happened, what to do (docs/UI.md pattern table > Errors).*/
    ui_message: z
      .string()
      .describe(
        "What the shell shows: specific title, what happened, what to do (docs/UI.md pattern table > Errors).",
      ),
    retriable: z.boolean(),
  })
  .strict()
  .describe(
    "The shape of one code in an error catalogue. Every package error the host wraps maps to one of these. home/spec/errors/errors.json is the populated catalogue for the platform; this is the shape it (and any other repo's catalogue) conforms to. See platform plan 2.1, 4.9, and docs/ENGINEERING.md > Errors.",
  );
export type ErrorEntry = z.infer<typeof ErrorEntry>;
