# Contributing to PEMEncrypt

<!-- TOC -->

* [Contributing to PEMEncrypt](#Contributing-to-PEMEncrypt)
  * [Git and Pull requests](#Git-and-Pull-requests)
  * [Overview](#Overview)
    * [Step by Step (High-Level)](#Step-by-Step-High-Level)
    * [Contributing Guidelines](#Contributing-Guidelines)
  * [Keeping in Touch](#Keeping-in-Touch)

<!-- /TOC -->

Thank you for your interest in helping PEMEncrypt grow! Below you'll find some guidelines around developing additional features and squashing bugs, including some how-to's to get started quick, general style guidelines, etc.

[![Waffle.io - Columns and their card count](https://badge.waffle.io/scrthq/PEMEncrypt.svg?columns=all)](https://waffle.io/scrthq/PEMEncrypt)

## Git and Pull requests

* Contributions are submitted, reviewed, and accepted using Github pull requests. [Read this article](https://help.github.com/articles/using-pull-requests) for some details. We use the _Fork and Pull_ model, as described there. More info can be found here: [Forking Projects](https://guides.github.com/activities/forking/)
* Please make sure to leave the `Allow edits from maintainers` box checked when submitting PR's so that any edits can be made by maintainers of the repo directly to the source branch and into the same PR. More info can be found here: [Allowing changes to a pull request branch created from a fork](https://help.github.com/articles/allowing-changes-to-a-pull-request-branch-created-from-a-fork/#enabling-repository-maintainer-permissions-on-existing-pull-requests)

## Overview

### Step by Step (High-Level)

Here's the overall flow of making contributions:
1. Fork the repo
2. Make your edits / additions on your fork
3. Push your changes back to your fork on GitHub
4. Submit a pull request
5. Pull request is reviewed. Any necessary edits / suggestions will be made
6. Once changes are approved, the pull request is merged into the origin's master branch and deployed to the PowerShell Gallery once CI tests pass in AppVeyor

### Contributing Guidelines

Please follow these guidelines for any content being added:

* **ALL functions must...**
    * work in the supported PowerShell versions by this module
    * work in any OS;
        * any code that includes paths must build the path using OS-agnostic methods, i.e. by using `Resolve-Path`, `Join-Path` and `Split-Path`
        * paths also need to use correct casing, as some OS's are case-sensitive in terms of paths
* **Public functions must...**
    * include comment-based help (this is used to drive the Wiki updates on deployment)
    * include Write-Verbose calls to describe what the function is doing (CI tests will fail the build if any don't)
    * be placed in the correct APU/use-case folder in the Public sub-directory of the module path (if it's a new API/use-case, create the new folder as well)
    * use `SupportsShouldProcess` if...
        * the function's verb is `Remove` or `Set`.
        * it can be included on `Update` functions as well, if felt that the actions executed by the function should be guarded
        * `Get` functions should **never** need `SupportsShouldProcess`
* **Every Pull Request must...**
    > These can be added in during the pull request review process, but are nice to have if possible
    * have the module version bumped appropriately in the manifest (Major for any large updates, Minor for any new functionality, Patch for any hotfixes)
    * have an entry in the Changelog describing what was added, updated and/or fixed with this version number
        * *Please follow the same format already present*
    * have an entry in the ReadMe's `Most recent changes` section describing what was added, updated and/or fixed with this version number
        * *Please follow the same format already present*
        * *This can be copied over from the Changelog entry*

## Keeping in Touch

For any questions, comments or concerns outside of opening an issue, please reach out:
* on the SCRT HQ Slack: `scrthq.slack.com`. [Click here](https://scrthq-slack-invite.herokuapp.com/) to get an invite!
* on the SCRT HQ Discord: [Click here](https://discord.gg/G66zVG7) to get an invite!
* `@scrthq` on the [PowerShell Slack](http://slack.poshcode.org/) if you're on there as well!
* [`@scrthq`](https://twitter.com/scrthq) on Twitter
