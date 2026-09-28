# Stream inventory

Streams belong to a saved Study Area and retain stable identities across context
revisions. The spatial creation path selects reference flowlines and constructs a
corridor through clipping and buffering; see `drainage-exploration.md` and
`dev/schemas/stream-selection.md`.

An optional names-only form records an initial inventory when geometry is not yet
available. Names must be nonempty and unique. It does not replace an existing
inventory or infer a watershed. One eligible names-only Stream can receive its
area by exact identity. General Stream geometry replacement/removal and multiple
names-only area assignment require further implementation.

Saved inventory supports naming and Reach creation, combination and splitting.
Explicit reopen clears transient editors; in-place revisions retain compatible
same-Study draft state. Article 03 and the analyst guide own the operational path;
store/module tests cover parent identity, stale saves and preserved originals.
