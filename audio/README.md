# Sounds

`sfx/` is where a sound effect goes, named by the sound bank's row for it
(`data/db/sounds/sounds.sql`): `res://audio/sfx/<id>.wav`. Nothing is made in
code: a sound is silent until its file is here and its row is switched on.
Each row's description is the prompt to give Stable Audio by hand; save what
comes back here, run the editor or `godot --import` once, set the row's
`use_flag` to `Y` and rebuild the database, and the game plays it. Nothing
here yet: every flag is `N`, and the game is silent.
