# PowerShell 5.1-compatible transport. No Add-Type and no scan tree in PowerShell.
function Start-DiskHelper {
    param([Parameter(Mandatory=$true)][string]$Executable,[Parameter(Mandatory=$true)][string]$Manifest)
    $meta=Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
    if($meta.Protocol -ne 1 -or $meta.File -ne [IO.Path]::GetFileName($Executable)){throw 'Unsupported helper manifest.'}
    if((Get-FileHash -LiteralPath $Executable -Algorithm SHA256).Hash -ne $meta.Sha256){throw 'Helper checksum mismatch. Rebuild or obtain a fresh package.'}
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=[IO.Path]::GetFullPath($Executable);$start.UseShellExecute=$false;$start.CreateNoWindow=$true
    $start.RedirectStandardInput=$true;$start.RedirectStandardOutput=$true
    $start.StandardOutputEncoding=[Text.UTF8Encoding]::new($false)
    $process=[Diagnostics.Process]::new();$process.StartInfo=$start
    try {
        $null=$process.Start()
        # Use our own UTF-8 writer: Framework defaults differ from PowerShell 7.
        $writer=[IO.StreamWriter]::new($process.StandardInput.BaseStream,[Text.UTF8Encoding]::new($false))
        $writer.AutoFlush=$true
        $session=[pscustomobject]@{Process=$process;Writer=$writer;Hello=$null;LastResponseBytes=0;Closed=$false}
        $session.Hello=Read-DiskHelperResponse $session
        if($session.Hello.type -ne 'hello' -or $session.Hello.protocol -ne 1 -or $session.Hello.version -ne $meta.Version){throw 'Helper handshake mismatch.'}
        return $session
    } catch {
        try {if(-not $process.HasExited){$process.Kill()}} catch {}
        $process.Dispose();throw
    }
}
function Read-DiskHelperResponse {
    param($Session,[int]$TimeoutMilliseconds=30000)
    $pending=$Session.Process.StandardOutput.ReadLineAsync()
    if(-not $pending.Wait($TimeoutMilliseconds)){throw 'Helper response timed out.'}
    $line=$pending.Result
    if($null -eq $line){throw 'Helper exited before replying.'}
    $Session.LastResponseBytes=[Text.Encoding]::UTF8.GetByteCount($line)
    $reply=$line | ConvertFrom-Json
    if($reply.type -eq 'error'){throw ('Helper: '+$reply.message)}
    return $reply
}
function Invoke-DiskHelper {
    param($Session,[Parameter(Mandatory=$true)][hashtable]$Request)
    if($Session.Closed -or $Session.Process.HasExited){throw 'Helper session is closed.'}
    $Session.Writer.WriteLine(($Request | ConvertTo-Json -Compress -Depth 6))
    return Read-DiskHelperResponse $Session
}
function Stop-DiskHelper {
    param($Session)
    if($null -eq $Session -or $Session.Closed){return}
    try {
        if(-not $Session.Process.HasExited){
            $Session.Writer.WriteLine('{"command":"quit"}')
            if(-not $Session.Process.WaitForExit(2000)){$Session.Process.Kill();$Session.Process.WaitForExit()}
        }
    } finally {$Session.Closed=$true;$Session.Writer.Dispose();$Session.Process.Dispose()}
}
