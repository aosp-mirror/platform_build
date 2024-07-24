# Finalization tools
This folder contains automation and CI scripts for [finalizing](https://go/android-finalization) Android before release.

## Automation:
1. [Environment setup](./environment.sh). Set values for varios finalization constants.
1. [Finalize VINTF](./finalize-vintf-resources.sh). Prepare the branch for VINTF release.
1. [Finalize SDK](./finalize-sdk-resources.sh). Prepare the branch for SDK release. SDK contains Android Java APIs and other stable APIs. Commonly referred as a 1st step.
1. [Finalize Android](./finalize-sdk-rel.sh). Mark branch as "REL", i.e. prepares for Android release. Any signed build containing these changes will be considered an official Android Release. Referred as a 2nd finalization step.
1. [Finalize VINTF and submit](./step-0.sh). Do Finalize VINTF step, create CLs, organize them into topic and send to Gerrit.
1. [Finalize SDK and submit](./step-1.sh). Do Finalize SDK step, create CLs, organize them into topic and send to Gerrit.
1. [Finalize Android and submit](./step-2.sh). Do [Finalize Android](./finalize-sdk-rel.sh) step, create  CLs, organize them into topic and send to Gerrit.

## CI:
Performed in build targets in Finalization branches.
1. [Finalization Step 0, git_main-fina-0-release](https://android-build.corp.google.com/build_explorer/branch/git_main-fina-0-release). Test Finalize VINTF.
1. [Finalization Step 1, git_main-fina-1-release](https://android-build.corp.google.com/build_explorer/branch/git_main-fina-1-release). Test Finalize VINTF, Finalize SDK.
1. [Finalization Step 2, git_main-fina-2-release](https://android-build.corp.google.com/build_explorer/branch/git_main-fina-2-release). Test Finalize VINTF, Finalize SDK, and [2nd step/Finalize Android](./finalize-sdk-rel.sh). Use [local finalization](./localonly-steps.sh) to build and copy presubmits.
1. [Local finalization steps](./localonly-steps.sh) are done only during local testing or in the CI lab. Normally these steps use artifacts from other builds.

## Utility:
[Full cleanup](./cleanup.sh). Remove all local changes and switch each project into head-less state. This is the best state to sync/rebase/finalize the branch.
