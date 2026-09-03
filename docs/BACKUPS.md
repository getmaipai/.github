# Backups: integrated, scheduled, secure, on every platform

Full source: platform plan section 2.5.

## Built from declarations

Core declares its stores; every package declares its persistent directory
and database with a `backup: hot | cold | exclude` mode (hot copies live,
cold pauses the package, exclude for rebuildable caches). Media libraries
declare themselves `library` (referenced, not copied by default). The
Storage page shows what a backup will contain and its size.

## Targets

Through a backup-agent port: `local` (a second disk or folder), `hub`
(robots and phones back up to the hub), `smb` (a NAS share). Later agents
(S3-compatible, a second hub) fit the same port. At least one off-machine
target is required before the Storage page stops warning. Never a
MaiPai-operated service, per the org's zero-phone-home rule in
[`CLAUDE.md`](../CLAUDE.md).

## Security

AES-256-GCM before leaving the machine, keyed from the keystore, never
inside the archive. An **emergency kit** is generated at setup (the backup
key and hub identity as a printable page and a file, shown once, with a
"print this" step). Credentials inside a backup keep their own encryption.
Archives are signed and a tampered one is refused. The agent's own
credentials live in the credentials center.

## Schedule and retention

Daily at a household-set time in the nightly window before updates, plus
before every update and restore. Retention: seven daily, four weekly,
three monthly, oldest pruned first, with a size cap per target. A failure
raises a Repairs item; two in a row notify admins. The robot backs up to
the hub when docked; a standalone robot backs up to USB or SMB. Go backs up
its downloads list and progress, never media files.

## Restore

The second screen of onboarding on hub and robot. Staged like an update:
verify, unpack beside live data, migrate, swap, health check. A failed
restore leaves the previous data untouched. Partial restore of one
person's data is available from the Storage page, which is also how a lost
robot is replaced.

## Restore drill

Every release restores the latest backup into a temporary data directory
and boots it headless with a sign-in, so "backups work" is proven each
release, not assumed. This is part of the release skill's gate before a
tag ships.
