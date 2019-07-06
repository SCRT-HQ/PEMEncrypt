try {
    $dllpath = [System.IO.Path]::Combine($PSScriptRoot,'BouncyCastle.Crypto.dll')
    Add-Type -Path $dllpath | Out-Null
}
catch {
    $global:Error.Remove($global:Error[0])
}
try {
    $dllpath = [System.IO.Path]::Combine($PSScriptRoot,'SCRTHQ.PEMEncrypt','bin','Debug','netstandard2.0','SCRTHQ.PEMEncrypt.dll')
    Add-Type -Path $dllpath | Out-Null
}
catch {
    $global:Error.Remove($global:Error[0])
}