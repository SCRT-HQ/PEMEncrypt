$private = Get-ChildItem (Join-Path $PSScriptRoot "Private") -Recurse -Filter "*.ps1"
$public = Get-ChildItem (Join-Path $PSScriptRoot "Public") -Recurse -Filter "*.ps1"

foreach ($function in ($private + $public)) {
    . $function.FullName
}

try {
    $bouncyCastleDll = [System.IO.Path]::Combine($PSScriptRoot,'bin','BouncyCastle.Crypto.dll')
    Add-Type -Path $bouncyCastleDll -ErrorAction SilentlyContinue | Out-Null
}
catch {
    $Global:Error.Remove($Global:Error[0])
}
try {
    $PEMEncrypt = [System.IO.Path]::Combine($PSScriptRoot,'bin','SCRTHQ.PEMEncrypt.dll')
    Add-Type -Path $PEMEncrypt -ReferencedAssemblies $bouncyCastleDll -ErrorAction SilentlyContinue | Out-Null
}
catch {
    $Global:Error.Remove($Global:Error[0])
}

Export-ModuleMember -Function $public.BaseName
