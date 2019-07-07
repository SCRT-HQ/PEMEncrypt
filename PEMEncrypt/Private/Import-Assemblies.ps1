function Import-Assemblies {
    Param()
    Begin {
        $dllPath = if ($PSVersionTable.PSVersion.Major -ge 6) {
            [System.IO.Path]::Combine($PSScriptRoot,'bin','netstandard')
        }
        else {
            [System.IO.Path]::Combine($PSScriptRoot,'bin','netfx')
        }
    }
    Process {
        try {
            $bouncyCastleDll = Join-Path $dllPath 'BouncyCastle.Crypto.dll'
            Add-Type -Path $bouncyCastleDll -ErrorAction SilentlyContinue | Out-Null
        }
        catch {
            $Global:Error.Remove($Global:Error[0])
        }
        try {
            $PEMEncrypt = Join-Path $dllPath 'SCRTHQ.PEMEncrypt.dll'
            Add-Type -Path $PEMEncrypt -ReferencedAssemblies $bouncyCastleDll -ErrorAction SilentlyContinue | Out-Null
        }
        catch {
            $Global:Error.Remove($Global:Error[0])
        }
    }
}
