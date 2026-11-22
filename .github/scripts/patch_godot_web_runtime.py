#!/usr/bin/env python3
"""Expose a narrow, awaited IndexedDB flush hook for the Godot 4.7.2 Web runtime.

Godot's Web template currently persists user:// through IDBFS autoPersist, but
does not expose its asynchronous sync completion to GDScript. This patch keeps
the runtime implementation and adds an Engine.rtenv method that drains queued
IDBFS autoPersist work, performs a final syncfs, and resolves only after the
IndexedDB transaction completes. An exact runtime anchor check makes template
changes fail the export instead of silently shipping an unpatched build.
"""

from pathlib import Path
import sys


RUNTIME_MARKER = "Module['obtSyncUserFS']=function(){return GodotFS.sync_userfs()};"
RUNTIME_OBJECT = "var GodotFS={ENOENT:44,_idbfs:false,_syncing:false,_mount_points:[],"
GODOT_OS_ANCHOR = "var GodotOS={request_quit:function(){},_async_cbs:[]"
SYNC_PREFIX = "sync:function(){if(GodotFS._syncing)"
SYNC_SUFFIX = "},copy_to_fs:function"

SYNC_IMPLEMENTATION = '''sync:function(){if(GodotFS._syncing){return GodotFS._syncPromise||Promise.resolve(new Error("User storage is already synchronizing"))}GodotFS._syncing=true;GodotFS._syncPromise=new Promise(function(resolve){FS.syncfs(false,function(error){if(error){GodotRuntime.error(`Failed to save IDB file system: ${error.message}`)}GodotFS._syncing=false;GodotFS._syncPromise=null;resolve(error)})});return GodotFS._syncPromise},sync_userfs:function(){if(!GodotFS._idbfs){return Promise.resolve(new Error("IndexedDB persistence is unavailable"))}if(GodotFS._userfsSyncPromise){return GodotFS._userfsSyncPromise}const mounts=GodotFS._mount_points.map(function(path){return FS.lookupPath(path).node.mount});GodotFS._userfsSyncPromise=new Promise(function(resolve){let settled=false;const timeout=setTimeout(function(){finish(new Error("Timed out waiting for browser storage to finish saving"))},30000);function finish(error){if(settled){return}settled=true;clearTimeout(timeout);GodotFS._userfsSyncPromise=null;resolve(error||null)}function waitForAutoPersist(){if(mounts.some(function(mount){return Boolean(mount.idbPersistState)})){setTimeout(waitForAutoPersist,0);return}GodotFS.sync().then(function(error){if(error){finish(error);return}if(mounts.some(function(mount){return Boolean(mount.idbPersistState)})){waitForAutoPersist();return}finish(null)}).catch(finish)}waitForAutoPersist()});return GodotFS._userfsSyncPromise},copy_to_fs:function'''


def patch_runtime(path: Path) -> bool:
    source = path.read_text(encoding="utf-8")
    if RUNTIME_MARKER in source:
        if source.count(RUNTIME_MARKER) != 1:
            raise RuntimeError("Godot runtime sync hook marker appears more than once")
        return False

    if source.count(RUNTIME_OBJECT) != 1:
        raise RuntimeError("Unexpected Godot Web runtime GodotFS object; expected one Godot 4.7.2 anchor")
    if source.count(GODOT_OS_ANCHOR) != 1:
        raise RuntimeError("Unexpected Godot Web runtime GodotOS anchor; refusing an unverified patch")
    if source.count(SYNC_PREFIX) != 1:
        raise RuntimeError("Unexpected GodotFS.sync implementation; refusing an unverified patch")

    start = source.index(SYNC_PREFIX)
    end = source.index(SYNC_SUFFIX, start)
    old_sync = source[start:end + len(SYNC_SUFFIX)]
    if not old_sync.startswith(SYNC_PREFIX) or not old_sync.endswith(SYNC_SUFFIX):
        raise RuntimeError("Could not isolate GodotFS.sync safely")
    source = source[:start] + SYNC_IMPLEMENTATION + source[end + len(SYNC_SUFFIX):]
    source = source.replace(RUNTIME_OBJECT, RUNTIME_OBJECT.replace("_mount_points:[],", "_mount_points:[],_syncPromise:null,_userfsSyncPromise:null,"), 1)
    source = source.replace(GODOT_OS_ANCHOR, RUNTIME_MARKER + GODOT_OS_ANCHOR, 1)
    if source.count(RUNTIME_MARKER) != 1 or "sync_userfs:function()" not in source:
        raise RuntimeError("Godot runtime sync hook verification failed")
    path.write_text(source, encoding="utf-8")
    return True


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: patch_godot_web_runtime.py web-build/index.js")
    target = Path(sys.argv[1])
    if not target.is_file():
        raise SystemExit(f"Godot Web runtime not found: {target}")
    changed = patch_runtime(target)
    print("Godot Web runtime persistence hook " + ("installed" if changed else "already installed"))
