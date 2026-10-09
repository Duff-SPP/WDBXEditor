# Runtime smoke test for raw WDBC fallback. Uses synthetic bytes only.
# Run after building WDBXEditor.sln on Windows with .NET Framework 4.6.1.
$ErrorActionPreference = 'Stop'

$exe = Join-Path $PSScriptRoot '..\WDBXEditor\bin\Release\WDBX Editor.exe'
$exe = [IO.Path]::GetFullPath($exe)
if (-not (Test-Path $exe)) { throw "Missing built WDBX Editor.exe at $exe" }
$assembly = [Reflection.Assembly]::LoadFrom($exe)
$databaseType = $assembly.GetType('WDBXEditor.Storage.Database', $true)
$flags = [Reflection.BindingFlags]::Static -bor [Reflection.BindingFlags]::Public -bor [Reflection.BindingFlags]::NonPublic
$databaseType.GetProperty('BuildNumber', $flags).SetValue($null, [int]12340, $null)
$reader = [Activator]::CreateInstance($assembly.GetType('WDBXEditor.Reader.DBReader', $true))
$dir = Join-Path ([IO.Path]::GetTempPath()) ('WDBXEditorRaw-' + [Guid]::NewGuid().ToString('N'))
[void](New-Item -Path $dir -ItemType Directory -Force)

function Assert([bool]$condition, [string]$reason) {
    if (-not $condition) { throw $reason }
}
function SameBytes([string]$left, [string]$right) {
    $a = [IO.File]::ReadAllBytes($left)
    $b = [IO.File]::ReadAllBytes($right)
    return [Convert]::ToBase64String($a) -ceq [Convert]::ToBase64String($b)
}
function New-Writer([string]$path, [uint32]$count, [uint32]$fieldCount, [uint32]$recordSize, [byte[]]$strings) {
    $writer = [IO.BinaryWriter]::new([IO.File]::Create($path))
    $writer.Write([Text.Encoding]::ASCII.GetBytes('WDBC'))
    $writer.Write($count)
    $writer.Write($fieldCount)
    $writer.Write($recordSize)
    $writer.Write([uint32]$strings.Length)
    return $writer
}

try {
    $strings = [byte[]](0,104,101,108,108,111,0,119,111,114,108,100,0)
    $source = Join-Path $dir 'UnknownAscension.dbc'
    $w = New-Writer $source 2 179 12 $strings
    try {
        $w.Write([uint32]42); $w.Write([uint32]1); $w.Write([uint32]1065353216)
        $w.Write([uint32]42); $w.Write([uint32]7); $w.Write([uint32]1077936128)
        $w.Write($strings)
    } finally { $w.Dispose() }

    $entry = $reader.Read($source)
    Assert $entry.Header.IsRawLayout 'Unknown WDBC did not select raw mode'
    Assert ($entry.Data.Rows.Count -eq 2) 'Wrong record count'
    Assert ($entry.Data.Columns.Count -eq 4) 'Wrong raw column count'
    Assert ([uint32]$entry.Data.Rows[0]['Field_000'] -eq 42) 'Wrong first field'
    Assert ([uint32]$entry.Data.Rows[1]['Field_000'] -eq 42) 'Duplicate first field rejected'
    Assert ($entry.Header.FieldCount -eq 179) 'Original header FieldCount not preserved'

    $unchanged = Join-Path $dir 'unchanged.dbc'
    $reader.Write($entry, $unchanged)
    Assert (SameBytes $source $unchanged) 'Unchanged raw save changed file bytes'

    $entry.Data.Rows[0]['Field_001'] = [uint32]13
    $edited = Join-Path $dir 'edited.dbc'
    $reader.Write($entry, $edited)
    $before = [IO.File]::ReadAllBytes($source)
    $after = [IO.File]::ReadAllBytes($edited)
    Assert ($before.Length -eq $after.Length) 'Editing changed file length'
    $changed = 0
    for ($i = 0; $i -lt $before.Length; $i++) {
        if ($before[$i] -ne $after[$i]) {
            $changed++
            Assert ($i -ge 24 -and $i -lt 28) 'Editing changed unrelated bytes'
        }
    }
    Assert ($changed -gt 0) 'Edit was not written'
    $reopened = $reader.Read($edited)
    Assert ([uint32]$reopened.Data.Rows[0]['Field_001'] -eq 13) 'Edited field did not survive reopen'
    Write-Host 'PASS: mismatched header, repeated first column, string preservation, edit/reopen'

    $short = Join-Path $dir 'NonAligned.dbc'
    $w = New-Writer $short 2 77 6 ([byte[]](0))
    try {
        $w.Write([uint32]100); $w.Write([byte]17); $w.Write([byte]34)
        $w.Write([uint32]200); $w.Write([byte]51); $w.Write([byte]68)
        $w.Write([byte]0)
    } finally { $w.Dispose() }
    $odd = $reader.Read($short)
    Assert ($odd.Data.Columns.Count -eq 4) 'Tail byte fields missing'
    Assert ([byte]$odd.Data.Rows[1]['TailByte_01'] -eq 68) 'Tail byte was not read'
    $oddSaved = Join-Path $dir 'nonaligned-saved.dbc'
    $reader.Write($odd, $oddSaved)
    Assert (SameBytes $short $oddSaved) 'Non-4-byte record changed in round trip'
    Write-Host 'PASS: non-4-byte record size and tail-byte round trip'

    $bad = Join-Path $dir 'InvalidLength.dbc'
    [IO.File]::WriteAllBytes($bad, [byte[]]([IO.File]::ReadAllBytes($source) + [byte]255))
    $rejected = $false
    try { [void]$reader.Read($bad) } catch { $rejected = $true }
    Assert $rejected 'Malformed file was not rejected'
    Write-Host 'PASS: invalid file size rejected'
}
finally {
    Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue
}
