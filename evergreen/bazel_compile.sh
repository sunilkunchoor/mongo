# Usage:
#   bazel_compile [arguments]
#
# Required environment variables:
# * ${targets} - List of build targets
#
# Optional environment variable(s):
# * ${args} - List of additional Bazel arguments (e.g.: "--config=clang-tidy")

# Needed for evergreen scripts that use evergreen expansions and utility methods.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" > /dev/null 2>&1 && pwd)"
. "$DIR/prelude.sh"

cd src

set -o errexit
set -o verbose

# Use `eval` to force evaluation of the environment variables in the echo statement:
eval echo "Execution environment: Targets: ${targets}"

source ./evergreen/bazel_RBE_supported.sh

if bazel_rbe_supported; then
  LOCAL_ARG=""
else
  LOCAL_ARG="--config=local"
fi

if [[ "${evergreen_remote_exec}" != "on" ]]; then
  LOCAL_ARG="$LOCAL_ARG --jobs=auto"
fi

ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]]; then
  ARCH="arm64"
elif [[ "$ARCH" == "ppc64le" || "$ARCH" == "ppc64" || "$ARCH" == "ppc" || "$ARCH" == "ppcle" ]]; then
  ARCH="ppc64le"
elif [[ "$ARCH" == "s390x" || "$ARCH" == "s390" ]]; then
  ARCH="s390x"
else
  ARCH="amd64"
fi

# Set the JAVA_HOME directories for ppc64le and s390x since their bazel binaries are not compiled with a built-in JDK.
# TODO(SERVER-86050): remove the branch once bazelisk is built on s390x & ppc64le
if [[ $ARCH == "ppc64le" ]]; then
  export JAVA_HOME="/usr/lib/jvm/java-21-openjdk"
elif [[ $ARCH == "s390x" ]]; then
  export JAVA_HOME="/usr/lib/jvm/java-21-openjdk"
fi

# TODO(SERVER-86050): remove the branch once bazelisk is built on s390x & ppc64le
if [[ $ARCH == "ppc64le" ]] || [[ $ARCH == "s390x" ]]; then
  BAZEL_BINARY=$TMPDIR/bazel
else
  BAZEL_BINARY=$TMPDIR/bazelisk
fi

for i in {1..5}; do
  eval $BAZEL_BINARY build --verbose_failures $LOCAL_ARG ${args} ${targets} && RET=0 && break || RET=$? && sleep 1
  echo "Bazel failed to execute, retrying..."
done

exit $RET
