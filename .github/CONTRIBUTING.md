# How to Contribute

<b>First of all thanks for taking the time and wanting to contribute to OpenGlance 👍🏼🎉</b>

## How can I start coding?

Before you start coding it is best to directly comment on the issue and tell everyone that you want to work on it. This prevents misunderstandings such that two persons start working on the same issue. We will then assign the issue to you as soon as possible.

Now that everyone knows that you wanna work on this issue you can start by forking the repository. This will create a copy of the repository on your GitHub account. After forking the repository you can clone it using the following command (be sure to use SSH). More info on how to clone a repository using SSH can be found [here](https://help.github.com/en/github/using-git/which-remote-url-should-i-use#cloning-with-ssh-urls):

```
git clone --recurse-submodules git@github.com:Usama3627/OpenGlance.git
```

## Installing the dependencies

After cloning your forked repository you have to install the dependencies of the project using [CocoaPods](https://cocoapods.org). The app uses CocoaPods for Sparkle and CocoaLumberjack, and Swift Package Manager (integrated in Xcode) for LaunchAtLogin. To install the CocoaPods dependencies execute the following command in the `iGlance` directory (in the following called `<root>/iGlance`) of the cloned repository:

```
pod install
```

If you get build errors after updating dependencies, run `pod install` again and let Xcode update the project settings when prompted.

## Setting up Xcode
To get started using Xcode you need to open the workspace file `<root>/iGlance/OpenGlance.xcworkspace`. To test if everything is setup correctly you can select the `OpenGlance` scheme at the upper left corner and run the app by clicking `Product > Run`. The app should be built now and start running.
To setup Xcode correctly with CocoaPods you should see a warning saying `"Update to recommended settings"`. By clicking on the warning and letting Xcode automatically update the project settings should fix the warning.

Now you are ready to start developing!🎉

## Getting ready for development

We have a `master` and a `development` branch in this repository. The `master` branch is responsible for all the releases. We push to this branch only if we release a new version. The development (as the name suggests) is for developing.
Therefore the next step is to create a new branch which is based on the `development` branch. To make it clear which issue is referenced by this branch your branch should be named after the following scheme:

`feature/<github_issue-id>-<issue_name>`
`bug-fix/<github_issue_id>-<issue_name>`

Now you can start coding 🎉💻🖥

## Making a release

Releases are produced automatically from a version tag. To cut a release, run the helper from the repository root:

```sh
./release.sh <version>   # e.g. ./release.sh 2.2.1
```

This bumps `Version.txt` and the Xcode `MARKETING_VERSION`, commits, tags `vX.Y.Z`, and pushes. The pushed tag triggers the release workflow, which builds the universal macOS app, publishes a GitHub Release with the ZIP and its SHA-256 checksum, and regenerates the Sparkle appcast (requires a `SPARKLE_EDDSA_PRIVATE_KEY` repository secret).

## Merging your code

After you finished implementing the feature you can create a new pull request.
Please create a pull request that will merge the changes on your `feature branch` into the `development` branch in the main repository. [Here](https://help.github.com/en/github/collaborating-with-issues-and-pull-requests/creating-a-pull-request-from-a-fork) you can find more info on how to create a pull request from your branch.

## Maintainers

The project is maintained by [@Usama3627](https://github.com/Usama3627).
