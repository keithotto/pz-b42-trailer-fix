# Trailer Fix (B42 Hotfix)

Project Zomboid Build 42 mod that fixes parked trailers never settling: drifting
on their own, pushing against hitched vehicles, and snapping into nearby cars in
multiplayer.

- Steam Workshop: https://steamcommunity.com/sharedfiles/filedetails/?id=3788274707
- Mod ID: `OT_B42TrailerFix`

## Repository layout

This repo is the Steam Workshop upload folder (`~/Zomboid/Workshop/OT_B42TrailerFix/`):

```
workshop.txt                      Workshop title, description, tags, visibility
preview.png                       Workshop thumbnail
Contents/mods/OT_B42TrailerFix/   The mod itself (mod.info, 42.0/...)
```

For local testing, symlink the mod into the game's mods folder:

```
ln -s ~/Zomboid/Workshop/OT_B42TrailerFix/Contents/mods/OT_B42TrailerFix ~/Zomboid/mods/OT_B42TrailerFix
```

## Workshop ID

The `id=3788274707` line in `workshop.txt` is the Steam Workshop item ID for this
mod's published page. The in-game Workshop uploader uses it to update the existing
item. If you fork this repo and want to publish your own copy, delete that line so
the uploader creates a new item under your account instead of failing to update one
you don't own.
