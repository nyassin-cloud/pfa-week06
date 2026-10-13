# Octo UV bridge

## App and bridge

Adobe Substance 3D Painter 12.1.4, using a **live port bridge**.
Our PowerShell client sends base64-encoded Python over HTTP to Painter's
local `/run.json` endpoint at port 60043, served by our own `octo_bridge.py`
plugin. We built both the server, client, and unwrap
workflow ourselves; no third-party MCP server is installed.

## How to run

Requirements: Windows, Substance 3D Painter 12.1.4, PowerShell, and your
OBJ model loaded in a Painter project. Python commands execute inside
Painter; no separate Python installation is required.

1. In Painter, select **Python > Plugins Folder**. Copy `octo_bridge.py`
   from this repository into that folder.
2. Select **Python > Reload Plugins Folder**, then enable **octo_bridge**
   in the Python menu. Painter's log should show
   `Octo bridge listening on 127.0.0.1:60043`.
   No special launch flag is required with our custom server.
   The optional launcher for Adobe's built-in server remains included:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\launch-painter.ps1
   ```

   For another installation location, append `-PainterExe "C:\path\Adobe Substance 3D Painter.exe"`.
   This launches with `--enable-remote-scripting`; our custom plugin operates
   independently of Adobe's built-in port.
3. Open your project and wait until the model is visible.
4. Check the live connection:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\bridge.ps1 -Action status
   ```

5. Ask your agent to unwrap the model, then have it run:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\bridge.ps1 -Action unwrap -Mesh "C:\Users\free\Downloads\octo.obj"
   ```

   Substitute your own OBJ path. The bridge saves a timestamped backup,
   reloads the OBJ with seams, islands, and packing recomputed and a
   margin of 2, then saves a separate unwrapped SPP after reload completes.
   It requests preservation of stroke positions, but changed UVs can affect
   existing painting; the backup keeps the original project recoverable.
6. Inspect the UV islands in Painter's 2D view. Results and a JSON status
   report are written to `results/`, excluded from Git.

If connection is refused, verify **Python > octo_bridge** is enabled and
check the Painter log for plugin errors. If the agent is running in a restricted environment, allow
local network access. The script must run on the same computer as Painter.
Use the source OBJ matching the project; the workflow reloads that mesh.

## Exact request and outcome

User's exact request:

> version 12.1.4.. and i have my objecta nd substance open. i want to uv mao it

The agent loaded `C:/Users/free/Downloads/octo.obj` into the open, empty
Painter application through our custom port bridge, creating a project
with automatic UV unwrapping enabled. Painter confirmed the mesh loaded
with 4,229 vertices and 6,992 faces. The agent then saved
`results/octo_unwrapped.spp` and checked that Painter was no longer busy
and that the saved project contained texture set `standardSurface8SG`.
The user confirmed the visible result: “yay it worked!!”.

Painter reported two limitations: the OBJ references a missing `octo.mtl`
file, and two faces were discarded by automatic unwrapping with their UVs
set to zero. The operation completed, but those warnings remain unresolved.
The source OBJ was not edited. A recording still needs to be made; the
initial successful run was not recorded.

## Issues encountered and how we handled them

| Issue | What we found | Fix or outcome |
| --- | --- | --- |
| Could not find the shortcut's Target field | We needed the Windows shortcut properties, rather than the executable's properties. | Opened the shortcut's **Shortcut** tab and appended the flag outside the quoted executable path. |
| Original model path was unavailable to the agent | The original location was `F:/Octo/scenes/octo.obj`. Access remained denied in the restricted workspace even after a permission grant. | The user put `octo.obj` in Downloads, where the agent could read it. |
| Painter opened empty after restarting | Restarting Painter did not reopen the model automatically. | The agent later created a project from the OBJ through our bridge. |
| Repeated port tests failed | `Test-NetConnection` returned `False` for port 60041. Some process checks showed Painter running without the flag, while another confirmed it running with the flag and still no connection. | We checked the actual process command line and startup logs. We did not determine the underlying cause of the built-in server failure. We replaced it with our own server plugin on port 60043. |
| Process-name diagnostic did not match | `Get-Process -Name` reported no match even though a CIM query identified Painter. | Used `Get-CimInstance Win32_Process` and the executable name to inspect its process ID and command line. |
| The agent could not install the plugin directly | Copying to Painter's configured user plugin folder remained denied in the agent environment after a permission grant. | The user copied `octo_bridge.py` from the workspace into `D:/Adobe/Adobe Substance 3D Painter/python/plugins`, reloaded the plugins folder, and enabled it. |
| Clicking the plugin appeared to do nothing | The server has no popup or new window. | Its log showed `Octo bridge listening on 127.0.0.1:60043`, and a status request returned Painter 12.1.4 with an empty project. |
| The PowerShell client returned an object-reference error | The Windows PowerShell web request failed until basic parsing was enabled. | Added `-UseBasicParsing` to `Invoke-WebRequest`; the bridge then connected successfully. |
| Git could not make the first local commit | No author identity was configured. | Set the repository-local author to `nyassin-cloud` with a GitHub noreply email. |
| Git push failed in the restricted workspace | The Git credential helper failed with an access-denied error. | Created the requested public GitHub repository in the signed-in browser and uploaded the bridge, launcher, and README as three meaningful commits. Later updates use the same browser workflow. |
| OBJ material file was missing | Painter could not find `octo.mtl`. | The geometry still loaded. This warning is unresolved; the matching MTL would need to accompany the OBJ to recover its source material information. |
| Two faces could not be automatically unwrapped | Painter assigned those faces zero UVs. | Saved the successful overall unwrap and documented the warning. The two faces still need mesh inspection before treating the asset as production-ready. |
| First successful run was not recorded | The result was visible, but the recording had not started. | Repeat the real bridge operation while recording; do not represent the first run as recorded. |

## Why the custom server works

`octo_bridge.py` starts a Python HTTP server bound to `127.0.0.1:60043`.
HTTP worker threads queue requests. A Qt timer drains that queue on
Painter's main thread, where the Painter API commands execute. The server
returns JSON results or tracebacks to our PowerShell client. This is our
own app-side bridge, not just an installed third-party integration.
It accepts Python code from local clients; disable the plugin when done.

## Recording (60 seconds maximum)

- Before recording: keep the plugin installed, save your project, close
  Painter, and prepare the terminal and agent chat so switching is quick.
- 0–10 seconds: start recording and open Painter. The custom plugin needs
  no launch flag. If it is not enabled automatically, enable **Python > octo_bridge**.
- 10–20 seconds: ask the agent, “Load my Octo OBJ, automatically UV unwrap it, and save a new Painter project.”
- 20–45 seconds: show the agent running the unwrap bridge and the operation
  completing in Painter. If launch/loading takes too long to fit under one
  minute, start the final take with Painter already open and the terminal visible.
- 45–60 seconds: show the UV islands in the 2D view and the saved result.

The recording must capture a real agent request and bridge execution.
Add the video or its link here after recording. Submit the GitHub repository
URL for the assignment.

## References

- [Adobe remote scripting](https://experienceleague.adobe.com/en/docs/substance-3d-dev/painter-python/tutorials/remote-control)
- [Adobe project and auto-unwrap API](https://experienceleague.adobe.com/en/docs/substance-3d-dev/painter-python/api/substancepainter-package/project)
