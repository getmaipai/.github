# Training models (wake words, and anything like them)

Pinned from `CLAUDE.md`'s "Topic docs" index. Load this whenever a session
trains or retrains a model (wake words, detectors, or anything similar).

Learned the hard way on 2026-08-31, when a shipped "Hey MaiPai" detector scored
0.955 on its own phrase and 0.979 on "hey my bike". These apply to any model we
train, not just wake words.

- **Verify the training data landed; never assume it.** Optional data packs are
  downloaded best-effort so an unattended install cannot hard-fail, which means
  a silent failure produces a quietly worse model and nothing says so. Every
  detector on the hub had been trained with the room-impulse pack, the
  real-noise pack and the 180 MB real-negative bank all absent. A training
  entry point checks each component is present and refuses to run without them.
- **Validate on real speech through the real microphone, before shipping.** The
  broken model scored 0.98 on synthesised speech, which is how it passed. Its
  own manifest recorded 0.977 accuracy, measured on synthetic validation data.
  A number produced by the same generator that made the training set is not
  evidence the thing works.
- **Train against near misses, not just unrelated phrases.** The negatives had
  volume of "hey <noun>" and not one possessive, so nothing taught the detector
  that the syllable after "hey" being "my" was not enough. Negatives have to
  include the confusions people actually produce, in the shapes they actually
  say them.
- **Harvest the real failures and train on those.** Audio from the household
  that falsely triggered a detector is the highest-value negative data there
  is: the right voice, the right room, the right microphone. Keep a path for
  it, and use it on the next retrain.
- **Never let unverified audio become training data.** Transcribe or otherwise
  confirm every clip before it is used. A clip assumed to be a near miss but
  actually containing the wake phrase teaches the model to reject its own name,
  which is worse than the bug being fixed. When a clip cannot be confirmed,
  drop it: certainty beats marginal data.
- **Household audio never enters a repo.** Recordings live under a gitignored
  data directory on the machine that needs them, and are copied, never
  committed. This is the family-data rule, applied to training sets.
- **When a model is retrained, retrain everything trained the same way.** A
  data-level fault is never confined to the one model whose symptom was
  noticed.
