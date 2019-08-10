function Unprotect-SecureString {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory,Position = 0)]
        [SecureString]
        $SecureString
    )
    Process {
        [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR(
                $SecureString
            )
        )
    }
}
