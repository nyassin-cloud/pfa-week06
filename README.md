# Octo UV bridge

## App and bridge

Adobe Substance 3D Painter 12.1.4, using a **live port bridge**.
Our PowerShell client sends base64-encoded Python over HTTP to Painter's
local `/run.json` endpoint at port 60041. We built the client and unwrap
workflow ourselves; no third-party MCP server is installed.

## How to run

Requirements: Windows, Substance 3D Painter 12.1.4, PowerShell, and your
OBJ model loaded in a Painter project. Python commands execute inside
Painter; no separate Python installation is required.

1. Save your project and close all Painter windows.
2. Open a PowerShell terminal in this repository. Launch Painter:

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\launch-painter.ps1
   ```

   For another installation location, append `-PainterExe "C:\path\Adobe Substance 3D Painter.exe"`.
   This launches with `--enable-remote-scripting`. Start only one Painter instance.
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

If connection is refused, verify Painter was fully closed before launching
with the flag. If the agent is running in a restricted environment, allow
local network access. The script must run on the same computer as Painter.
Use the source OBJ matching the project; the workflow reloads that mesh.

## Exact request and outcome

User's exact request:

> version 12.1.4.. and i have my objecta nd substance open. i want to uv mao it

The chosen object is `octo.obj`. The bridge has been written. **Live execution
is pending:** the connection check currently reports connection refused.
No successful unwrap or visual inspection is claimed yet. Update this
section with the actual result after the live run and recording.

## Recording (60 seconds maximum)

- 0–10 seconds: show the terminal and Painter with the original model.
- 10–20 seconds: ask the agent, “UV unwrap my Octo object in Substance Painter.”
- 20–45 seconds: show the agent running the unwrap bridge and the operation
  completing in Painter. Prepare the launch and open project before recording.
- 45–60 seconds: show the UV islands in the 2D view and the saved result.

The recording must capture a real agent request and bridge execution.
Add the video or its link here after recording. Submit the GitHub repository
URL for the assignment.

## References

- [Adobe remote scripting](https://experienceleague.adobe.com/en/docs/substance-3d-dev/painter-python/tutorials/remote-control)
- [Adobe project and auto-unwrap API](https://experienceleague.adobe.com/en/docs/substance-3d-dev/painter-python/api/substancepainter-package/project)
