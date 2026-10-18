# Sounds

`sfx/` is where a made sound effect goes, named by the sound bank's row for it
(`data/db/sounds/sounds.sql`): `res://audio/sfx/<id>.wav`. Each row's
description is the prompt to give Stable Audio by hand; save what comes back
here, run the editor or `godot --import` once, set the row's `use_flag` to `Y`
and rebuild the database, and the game plays the file in the synthesised
sound's place. Nothing here yet: every flag is `N`, and every sound is still
synthesised at boot (`app/audio/audio.gd`).
