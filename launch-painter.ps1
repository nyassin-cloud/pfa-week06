param([string]$PainterExe = 'E:\Adobe\Adobe Substance 3D Painter\Adobe Substance 3D Painter.exe')
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $PainterExe -PathType Leaf)) { throw "Painter executable not found: $PainterExe" }
# Run from your desktop terminal after saving and closing existing Painter windows.
Start-Process -FilePath $PainterExe -ArgumentList '--enable-remote-scripting'
