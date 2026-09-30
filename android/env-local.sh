#!/bin/sh
# Optional workspace-local toolchain installed during this milestone. Source from android/.
export JAVA_HOME="$PWD/.toolchain/amazon-corretto-17.jdk/Contents/Home"
export ANDROID_HOME="$PWD/.toolchain/sdk"
export GRADLE_USER_HOME="$PWD/.toolchain/gradle-home"
export ANDROID_AVD_HOME="$PWD/.toolchain/avd"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
