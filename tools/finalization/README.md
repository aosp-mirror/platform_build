# Finalization tools
This folder contains automation and CI scripts for [finalizing](https://go/android-finalization) Android before release.

## Automation:
1. [Environment setup](./environment.sh). Set values for varios finalization constants.
2. [Finalize SDK](./finalize-aidl-vndk-sdk-resources.sh). Prepare the branch for SDK release. SDK contains Android Java APIs and other stable APIs. Commonly referred as a 1st step.
3. [Finalize Android](./finalize-sdk-rel.sh). Mark branch as "REL", i.e. prepares for Android release. Any signed build containing these changes will be considered an official Android Release. Referred as a 2nd finalization step.
4. [Finalize SDK and submit](./step-1.sh). Do [Finalize SDK](./finalize-aidl-vndk-sdk-resources.sh) step, create CLs, organize them into topic and send to Gerrit.
  a. [Update SDK and submit](./update-step-1.sh). Same as above, but updates the existings CLs.
5. [Finalize Android and submit](./step-2.sh). Do [Finalize Android](./finalize-sdk-rel.sh) step, create  CLs, organize them into topic and send to Gerrit.
  a. [Update Android and submit](./update-step-2.sh). Same as above, but updates the existings CLs.

## CI:
Performed in build targets in Finalization branches.
1. [Finalization Step 1 for Main, git_main-fina-1-release](https://android-build.googleplex.com/builds/branches/git_main-fina-1-release/grid). Test [1st step/Finalize SDK](./finalize-aidl-vndk-sdk-resources.sh).
2. [Finalization Step 1 for UDC, git_udc-fina-1-release](https://android-build.googleplex.com/builds/branches/git_udc-fina-1-release/grid). Same but for udc-dev.
3. [Finalization Step 2 for Main, git_main-fina-2-release](https://android-build.googleplex.com/builds/branches/git_main-fina-2-release/grid). Test [1st step/Finalize SDK](./finalize-aidl-vndk-sdk-resources.sh) and [2nd step/Finalize Android](./finalize-sdk-rel.sh). Use [local finalization](./localonly-steps.sh) to build and copy presubmits.
4. [Finalization Step 2 for UDC, git_udc-fina-2-release](https://android-build.googleplex.com/builds/branches/git_udc-fina-2-release/grid). Same but for udc-dev.
5. [Local finalization steps](./localonly-steps.sh) are done only during local testing or in the CI lab. Normally these steps use artifacts from other builds.

## Utility:
[Full cleanup](./cleanup.sh). Remove all local changes and switch each project into head-less state. This is the best state to sync/rebase/finalize the branch.
