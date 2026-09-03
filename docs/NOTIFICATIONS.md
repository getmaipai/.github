# The notification system

Full source: platform plan section 2.6.

## Events are declared, not invented

A package or core declares each notification: `id`, `level` (`immediate`,
`time_sensitive`, `passive`), `audience` (a person, the household, admins,
parents of a child), a plain-language template, optional `actions[]`, a
default channel set, and a `privacy` flag (never on a shared screen). The
catalog lint refuses a notification without a level and a template.
Repairs, Updates, backups, credentials, and robot health all use the same
declarations, nothing bespoke.

## Levels

- **`immediate`**: delivers now, everywhere, through quiet hours. Someone
  at the door, a safety-flagged turn for a parent, a robot fallen or stuck,
  a security action awaiting confirmation.
- **`time_sensitive`**: delivers now but is held during quiet hours. A
  timer, a reminder, a download finished, someone arrived home.
- **`passive`**: batched into a digest up to three times a day at
  household-set times. Updates ready, a Repairs item, the weekly family
  audio summary, new episodes.

Quiet hours are set per household and per person; a child's are set by a
parent. Rate limits apply per event id. Per-channel and per-event switches
live in Profile.

## Channels, all inside the house

The shell's notification center and browser push through the hub's own
push endpoint on the LAN; Go local notifications from the hub's event
stream, with a TV overlay and speech through a companion if present; the
robot speaks once at a natural moment (`immediate` interrupts) and turns
actions into a spoken question; pods and Desktop use the same overlay and
chime; email and SMS only as later integration packages. Any channel that
would need a third-party relay off the LAN is off by default and listed on
the privacy page, per the org's zero-phone-home rule in
[`CLAUDE.md`](../CLAUDE.md).

## Routing

To the person on every device they are signed into, deduplicated by event
id (read on the phone clears the TV), never to a shared screen when
`privacy` is set. Household events go to every adult; a child's events go
to the child and, when the level says so, their parents. Actions round-trip
once with the idempotency rule.

## Visible after the fact

A thirty-day center per person with the digest expanded, and an admin log
of what fired, to whom, and how.
