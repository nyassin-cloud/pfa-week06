param(
    [ValidateSet('status','unwrap')][string]$Action = 'status',
    [string]$Mesh = 'C:\Users\free\Downloads\octo.obj',
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'results')
)
$ErrorActionPreference = 'Stop'
function Send-Painter([string]$Code) {
    $body = @{python = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($Code))} | ConvertTo-Json -Compress
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:60043/run.json' -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 30
        try { $decoded = $response.Content | ConvertFrom-Json } catch { $decoded = $null }
        if ($decoded -and $decoded.error) { throw $decoded.error }
        $response.Content
    } catch {
        throw "Painter bridge failed: $($_.Exception.Message). Enable octo_bridge in Painter's Python menu."
    }
}
if ($Action -eq 'status') {
    Send-Painter @'
import json
import substance_painter as sp
json.dumps({"version": list(sp.application.version_info()), "open": sp.project.is_open(), "busy": sp.project.is_busy(), "project": sp.project.file_path() if sp.project.is_open() else None, "mesh": sp.project.last_imported_mesh_path() if sp.project.is_open() else None})
'@
    exit
}
if (-not (Test-Path -LiteralPath $Mesh -PathType Leaf)) { throw "Mesh not found: $Mesh" }
$meshPath = (Resolve-Path -LiteralPath $Mesh).Path
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$outputPath = (Resolve-Path -LiteralPath $OutputDirectory).Path
# JSON string literals are also valid Python strings for these Windows paths.
$meshLiteral = ConvertTo-Json -InputObject $meshPath -Compress
$outputLiteral = ConvertTo-Json -InputObject $outputPath -Compress
$started = Get-Date
Send-Painter @"
import json, pathlib, datetime, traceback
import substance_painter as sp
if not sp.project.is_open():
    raise RuntimeError('Open your Octo project first.')
if not sp.project.is_in_edition_state() or sp.project.is_busy():
    raise RuntimeError('Wait for Painter to finish loading.')
_octo_dir = pathlib.Path($outputLiteral)
_octo_stamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S_%f')
_octo_backup = str(_octo_dir / ('octo_before_' + _octo_stamp + '.spp'))
_octo_result = str(_octo_dir / ('octo_unwrapped_' + _octo_stamp + '.spp'))
_octo_report = _octo_dir / ('unwrap_' + _octo_stamp + '.json')
_octo_state = {'state': 'starting', 'mesh': $meshLiteral, 'backup': _octo_backup, 'result': _octo_result}
def _octo_write():
    _octo_report.write_text(json.dumps(_octo_state, indent=2), encoding='utf-8')
sp.project.save_as_copy(_octo_backup)
_octo_state['state'] = 'unwrapping'
_octo_write()
def _octo_saved():
    try:
        sp.project.save_as(_octo_result)
        _octo_state['state'] = 'saved'
    except Exception:
        _octo_state['state'] = 'error'
        _octo_state['error'] = traceback.format_exc()
    _octo_write()
def _octo_reloaded(status):
    if status == sp.project.ReloadMeshStatus.SUCCESS:
        _octo_state['state'] = 'saving'
        _octo_write()
        sp.project.execute_when_not_busy(_octo_saved)
    else:
        _octo_state['state'] = 'error'
        _octo_state['error'] = str(status)
        _octo_write()
_octo_settings = sp.project.MeshReloadingSettings(preserve_strokes=True, auto_unwrap_settings=sp.project.AutoUnwrapSettings(recompute_seams=True, recompute_uv_islands=True, recompute_packing=True, margin_size=2.0))
sp.project.reload_mesh($meshLiteral, _octo_settings, _octo_reloaded)
"@
Write-Host 'Unwrap requested. Waiting for Painter to reload and save...'
$deadline = (Get-Date).AddMinutes(5)
do {
    Start-Sleep -Seconds 2
    $report = Get-ChildItem -LiteralPath $outputPath -Filter 'unwrap_*.json' | Where-Object { $_.LastWriteTime -ge $started } | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($report) {
        $state = Get-Content -LiteralPath $report.FullName -Raw | ConvertFrom-Json
        if ($state.state -eq 'saved') { $state | ConvertTo-Json; exit 0 }
        if ($state.state -eq 'error') { throw $state.error }
    }
} while ((Get-Date) -lt $deadline)
throw 'Timed out. Inspect Painter and the JSON report before running again.'
