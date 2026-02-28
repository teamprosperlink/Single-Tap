$base = "C:\Users\teamp\OneDrive\Documents\Single-Tap"

# Helper: delete a directory including symlinks using cmd rd
function Remove-DirFull($path) {
  if (-not (Test-Path $path)) { Write-Host "Not found: $path"; return }
  # First remove symlinks inside .plugin_symlinks manually
  $symlinkDir = Join-Path $path ".plugin_symlinks"
  if (Test-Path $symlinkDir) {
    Get-ChildItem -Path $symlinkDir -Force | ForEach-Object {
      if ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
        cmd /c "rmdir /q `"$($_.FullName)`"" 2>$null
      }
    }
  }
  # Then delete the rest
  $empty = "C:\Temp\empty_ephemeral"
  New-Item -ItemType Directory -Path $empty -Force | Out-Null
  robocopy $empty $path /MIR /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
  Remove-Item $path -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item $empty -Recurse -Force -ErrorAction SilentlyContinue
  Write-Host "Deleted: $path"
}

# Clear build (long paths via robocopy)
$buildPath = "$base\build"
if (Test-Path $buildPath) {
  $empty = "C:\Temp\empty_build"
  New-Item -ItemType Directory -Path $empty -Force | Out-Null
  robocopy $empty $buildPath /MIR /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
  Remove-Item $buildPath -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item $empty -Recurse -Force -ErrorAction SilentlyContinue
  Write-Host "Deleted: build"
} else {
  Write-Host "Not found: build"
}

# Clear .dart_tool
$dartTool = "$base\.dart_tool"
if (Test-Path $dartTool) {
  Remove-Item $dartTool -Recurse -Force -ErrorAction SilentlyContinue
  Write-Host "Deleted: .dart_tool"
} else {
  Write-Host "Not found: .dart_tool"
}

# Clear all platform ephemeral folders (handling symlinks)
Remove-DirFull "$base\windows\flutter\ephemeral"
Remove-DirFull "$base\macos\Flutter\ephemeral"
Remove-DirFull "$base\linux\flutter\ephemeral"
Remove-DirFull "$base\ios\Flutter\ephemeral"
Remove-DirFull "$base\android\flutter\ephemeral"

Write-Host "Clean complete."
