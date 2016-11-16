#!/usr/bin/env bash
#
# This is the build script for Ubuntu Launchpad
# https://launchpad.net/~pbek/+archive/ubuntu/qownnotes
#
# We will need some packages to execute this locally:
# sudo apt-get install build-essential autoconf automake autotools-dev dh-make debhelper devscripts fakeroot xutils lintian pbuilder cdbs
#
# The GPG public key $GPG_PUBLIC_KEY also has to be in place locally
# Also a ~/.dput.cf has to be in place
#

# uncomment this if you want to force a version
#QOWNNOTES_VERSION=16.08.1.2

BRANCH=develop
#BRANCH=master
UBUNTU_RELEASES=( "vivid" "wily" "xenial" "yakkety", "zesty" )


DATE=$(LC_ALL=C date +'%a, %d %b %Y %T %z')
PROJECT_PATH="/tmp/QOwnNotes-$$"
CUR_DIR=$(pwd)
UPLOAD="true"
DEBUILD_ARGS=""
GPG_PUBLIC_KEY=F5161BD3
export DEBFULLNAME="Patrizio Bekerle"
export DEBEMAIL="patrizio@bekerle.com"


while test $# -gt 0
do
    case "$1" in
        --no-upload) UPLOAD="false"
            ;;
        --no-orig-tar-upload) DEBUILD_ARGS="-sd"
            ;;
    esac
    shift
done

echo "Started the debian source packaging process, using latest '$BRANCH' git tree"

if [ -d $PROJECT_PATH ]; then
    rm -rf $PROJECT_PATH
fi

# checkout the source code
git clone --depth=50 git@github.com:pbek/QOwnNotes.git $PROJECT_PATH -b $BRANCH
cd $PROJECT_PATH

# checkout submodules
git submodule update --init

if [ -z $QOWNNOTES_VERSION ]; then
    # get version from version.h
    QOWNNOTES_VERSION=`cat src/version.h | sed "s/[^0-9,.]//g"`
else
    # set new version if we want to override it
    echo "#define VERSION \"$QOWNNOTES_VERSION\"" > src/version.h
fi

# set release string to disable the update check
echo "#define RELEASE \"Launchpad PPA\"" > src/release.h

changelogText="Released version $QOWNNOTES_VERSION"

echo "Using version $QOWNNOTES_VERSION..."

qownnotesSrcDir="qownnotes_${QOWNNOTES_VERSION}"

# copy the src directory
cp -R src $qownnotesSrcDir

# archive the source code
tar -czf $qownnotesSrcDir.orig.tar.gz $qownnotesSrcDir

changelogPath=debian/changelog


# build for every Ubuntu release
for ubuntuRelease in "${UBUNTU_RELEASES[@]}"
do
    :
    echo "Building for $ubuntuRelease..."
    cd $qownnotesSrcDir

    versionPart="$QOWNNOTES_VERSION-1ubuntu3ppa1~${ubuntuRelease}1"

    # update the changelog file
    #dch -v $versionPart $changelogText
    #dch -r $changelogText
    
    # create the changelog file
    echo "qownnotes ($versionPart) $ubuntuRelease; urgency=low" > $changelogPath
    echo "" >> $changelogPath
    echo "  * $changelogText" >> $changelogPath
    echo "" >> $changelogPath
    echo " -- $DEBFULLNAME <$DEBEMAIL>  $DATE" >> $changelogPath

    # launch debuild
    debuild -S -sa -k$GPG_PUBLIC_KEY $DEBUILD_ARGS
    cd ..

    # send to launchpad
    if [ "$UPLOAD" = "true" ]; then
        dput ppa:pbek/qownnotes qownnotes_${versionPart}_source.changes
    fi;
done


# remove everything after we are done
if [ -d $PROJECT_PATH ]; then
    rm -rf $PROJECT_PATH
fi
