try {
    $bouncyCastleDll = [System.IO.Path]::Combine($PSScriptRoot,'BouncyCastle.Crypto.dll')
    Add-Type -Path $bouncyCastleDll | Out-Null
}
catch {
    $global:Error.Remove($global:Error[0])
}
try {
    $PEMEncrypt = [System.IO.Path]::Combine($PSScriptRoot,'SCRTHQ.PEMEncrypt','bin','Debug','netstandard2.0','SCRTHQ.PEMEncrypt.dll')
    Add-Type -Path $PEMEncrypt -ReferencedAssemblies $bouncyCastleDll | Out-Null
}
catch {
    $global:Error.Remove($global:Error[0])
}