* [PEMEncrypt - ChangeLog](#PEMEncrypt---ChangeLog)
  * [0.1.1 - 2019-07-07](#011---2019-07-07)
  * [0.1.0 - 2019-07-07](#010---2019-07-07)

***

# PEMEncrypt - ChangeLog

## 0.1.1 - 2019-07-07

* Added CHANGELOG, CODE_OF_CONDUCT, CONTRIBUTING docs
* Updated README with relevant badges and overall info on installing/upgrading/using the module
* Added comment-based help on the included functions
* Removed KeyLength parameter from `Protect-PEMString` (now calculating from the Modulus BitLength, so it's not necessary to specify)
* Updated `*Key` parameters on both functions to allow passing the string formatted Key directly instead of the path to it.

## 0.1.0 - 2019-07-07

* Initial release to the PowerShell Gallery
* Included functions are `Protect-PEMString` and `Unprotect-PEMString`
* Fixed deployment issue
