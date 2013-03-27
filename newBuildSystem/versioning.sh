# Wird in Makefile.config inkludiert.


# Versioning

# isMasterBranch: Selbsterklärend (true/false)
# buildNumber: Jenkins BUILD_NUMBER oder 0
# repoDirtyState: "+" wenn uncommited changes vorhanden sind (+/)
# commitHash: Hash des commits, eventuell dirtyState (7b24eed/7b24eed+)
# versionType: Typ der Version (/b/n)


[[ "$(git symbolic-ref -q HEAD)" == "refs/heads/master" ]] && isMasterBranch=true || isMasterBranch=false
# Allow an optional name for the master branch in order
# to be able to test releases.
[[ "$MASTER_TEST_BRANCH" != "" && "$(git symbolic-ref -q HEAD)" == "refs/heads/$MASTER_TEST_BRANCH" ]] && isMasterBranch=true || isMasterBranch=false

buildNumber=${BUILD_NUMBER:-0}
repoDirtyState=$(test -z "$(git status --porcelain)" || echo "+")
commitHash=$(git rev-parse --short HEAD)$repoDirtyState

REVISION=${REVISION:+.$REVISION}

if $isMasterBranch ;then
	unset COMMIT
	versionType=${PRERELEASE:0:1}
else
    if [ ! -z "$commitHash" ]; then
        COMMIT=" ($commitHash)"
    else
        unset COMMIT
    fi
	versionType="n"
fi


version=${MAJOR}.${MINOR}${REVISION}${PRERELEASE}${COMMIT}
build_version=${buildNumber}${versionType}

