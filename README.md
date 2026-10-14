# fda-launcher

A tiny fixed-command launcher for giving **one** background job on macOS a privacy
permission such as Full Disk Access, without giving it to a whole interpreter.

## The problem

macOS ties privacy permissions (Full Disk Access, Files and Folders, ...) to the exact
executable that runs:

* A **script** cannot hold a permission. The process is the interpreter (`/bin/sh`,
  `python3`), so the interpreter would need it, and then *every* script run with that
  interpreter would have it.
* **Interpreter binaries change** with every update (`brew upgrade`, a new uv-managed Python),
  and the grant silently stops working.

## The fix

Build a small binary per job. It starts the job's command as a child process, and macOS
attributes the child's file access to this "responsible" launcher, the same way programs
started from Terminal use Terminal's permissions. Grant the launcher the permission once.

* The command is **compiled in**; command-line arguments are ignored, so the binary cannot be
  used to run anything else.
* The command must be an **absolute path** (no `PATH` lookup).
* `build-launcher.sh` **rebuilds only when** `launcher.c` or the command changes, so the grant
  survives updates of the job and of its interpreter.
* Signals (TERM, INT, HUP) are forwarded to the child; its exit code is passed through.

One launcher per job, never a shared one: a launcher that ran any command would be Full
Disk Access for anyone who can execute it. Separate launchers also show up by name in System
Settings and can be revoked one by one.

## Usage

```bash
./build-launcher.sh --name notes-sync -- /Users/me/.venvs/notes/bin/python -m notes_sync run
# -> ~/Library/Application Support/notes-sync/bin/notes-sync-launcher
```

With a launchd job (runs when a folder changes and every 30 minutes):

```bash
./build-launcher.sh --name notes-sync \
  --launchd local.notes-sync --watch "$HOME/Library/Group Containers/..." --interval 1800 \
  -- /Users/me/.venvs/notes/bin/python -m notes_sync run
```

Then: System Settings > Privacy & Security > Full Disk Access > **+** > Cmd+Shift+G, paste
the launcher path, and restart the job (`launchctl kickstart -k gui/$(id -u)/local.notes-sync`).

Requirements: a C compiler (`xcode-select --install`; already present if Homebrew is
installed).

## Notes

* Only jobs that read other apps' protected data need this (Voice Memos, Messages, Mail,
  Safari, ...). Most tools do not.
* Whoever can modify the job's own files (its virtualenv, its scripts) can run code with the
  permission. Keep those in a location only you can write to.
* Replacing the launcher binary changes its code signature, which invalidates the grant: a
  swapped binary does not inherit the permission.
* `./test.sh` checks quoting, argument isolation, exit codes, the rebuild stamp and the plist.

## License

MIT
