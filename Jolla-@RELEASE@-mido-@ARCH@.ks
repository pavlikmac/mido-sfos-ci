# DisplayName: Jolla mido/@ARCH@ (release) 1
# KickstartType: release
# SuggestedImageType: fs
# SuggestedArchitecture: armv7hl

user --name nemo --groups audio,video --password nemo
timezone --utc UTC
keyboard us
lang en_US.UTF-8

### Commands from /tmp/sandbox/usr/share/ssu/kickstart/part/default
part / --size 500 --ondisk sda --fstype=ext4

## No suitable configuration found in /tmp/sandbox/usr/share/ssu/kickstart/bootloader

repo --name=adaptation-community-common-mido-@RELEASE@ --baseurl=http://repo.merproject.org/obs/nemo:/devel:/hw:/common/sailfish_latest_@ARCH@/
repo --name=adaptation-community-mido-@RELEASE@ --baseurl=http://repo.merproject.org/obs/nemo:/devel:/hw:/xiaomi:/mido/sailfish_latest_@ARCH@/
repo --name=apps-@RELEASE@ --baseurl=https://releases.jolla.com/jolla-apps/@RELEASE@/@ARCH@/
repo --name=hotfixes-@RELEASE@ --baseurl=https://releases.jolla.com/releases/@RELEASE@/hotfixes/@ARCH@/
repo --name=jolla-@RELEASE@ --baseurl=https://releases.jolla.com/releases/@RELEASE@/jolla/@ARCH@/

%packages
@Jolla Configuration mido
#patterns-sailfish-device-configuration-mido
%end


%attachment
### Commands from /tmp/sandbox/usr/share/ssu/kickstart/attachment/mido
/boot/hybris-boot.img
/boot/hybris-updater-script
/boot/hybris-updater-unpack.sh
/boot/update-binary

%end

%pre
export SSU_RELEASE_TYPE=release
### begin 01_init
touch $INSTALL_ROOT/.bootstrap
### end 01_init
%end

%post
export SSU_RELEASE_TYPE=release
### begin 01_arch-hack
if [ "@ARCH@" == armv7hl ] || [ "@ARCH@" == armv7tnhl ]; then
    # Without this line the rpm does not get the architecture right.
    echo -n "@ARCH@-meego-linux" > /etc/rpm/platform

    # Also libzypp has problems in autodetecting the architecture so we force tha as well.
    # https://bugs.meego.com/show_bug.cgi?id=11484
    echo "arch = @ARCH@" >> /etc/zypp/zypp.conf
fi
### end 01_arch-hack
### begin 01_rpm-rebuilddb
# Rebuild db using target's rpm
echo -n "Rebuilding db using target rpm.."
rm -f /var/lib/rpm/__db*
rpm --rebuilddb
echo "done"
### end 01_rpm-rebuilddb
### begin 50_oneshot
# exit boostrap mode
rm -f /.bootstrap

# export some important variables until there's a better solution
export LANG=en_US.UTF-8
export LC_COLLATE=en_US.UTF-8
export GSETTINGS_BACKEND=gconf

# run the oneshot triggers for root and first user uid
UID_MIN=$(grep "^UID_MIN" /etc/login.defs |  tr -s " " | cut -d " " -f2)
DEVICEUSER=`getent passwd $UID_MIN | sed 's/:.*//'`

if [ -x /usr/bin/oneshot ]; then
   su -c "/usr/bin/oneshot --mic"
   su -c "/usr/bin/oneshot --mic" $DEVICEUSER
fi
### end 50_oneshot
### begin 60_ssu
if [ "$SSU_RELEASE_TYPE" = "rnd" ]; then
    [ -n "@RNDRELEASE@" ] && ssu release -r @RNDRELEASE@
    [ -n "@RNDFLAVOUR@" ] && ssu flavour @RNDFLAVOUR@
    # RELEASE is reused in RND setups with parallel release structures
    # this makes sure that an image created from such a structure updates from there
    [ -n "@RELEASE@" ] && ssu set update-version @RELEASE@
    ssu mode 2
else
    [ -n "@RELEASE@" ] && ssu release @RELEASE@
    ssu mode 4
fi
### end 60_ssu
### begin 70_sdk-domain

export SSU_DOMAIN=@RNDFLAVOUR@

if [ "$SSU_RELEASE_TYPE" = "release" ] && [[ "$SSU_DOMAIN" = "public-sdk" ]];
then
    ssu domain sailfish
fi
### end 70_sdk-domain
%end

%post --nochroot
export SSU_RELEASE_TYPE=release
### begin 01_release
if [ -n "$IMG_NAME" ]; then
    echo "BUILD: $IMG_NAME" >> $INSTALL_ROOT/etc/meego-release
fi
### end 01_release
### begin mido
cp $INSTALL_ROOT/etc/sailfish-release $IMG_OUT_DIR
### end mido
%end

%pack
export SSU_RELEASE_TYPE=release
### begin hybris
pushd $IMG_OUT_DIR

DEVICE=mido

VERSION_FILE=./sailfish-release
source $VERSION_FILE

# Locate rootfs tar.bz2 archive.
for filename in *.tar.bz2; do
    GEN_IMG_BASE=$(basename $filename .tar.bz2)
done

if [ ! -e "$GEN_IMG_BASE.tar.bz2" ]; then
    echo "No rootfs archive found, exiting ..."
    exit 1
fi

IMG_SIZE=$(du -h $GEN_IMG_BASE.tar.bz2 | cut -f1)

# Output filenames
DST_IMG_BASE=$ID-$DEVICE-$SAILFISH_FLAVOUR-$VERSION_ID@EXTRA_NAME@
DST_IMG=$DST_IMG_BASE.tar.bz2

# Copy boot image, updater scripts and updater binary into updater .zip tree.
mkdir -p updater/META-INF/com/google/android

mv update-binary updater/META-INF/com/google/android/update-binary
mv hybris-updater-script updater/META-INF/com/google/android/updater-script
mv hybris-updater-unpack.sh updater/updater-unpack.sh
mv hybris-boot.img updater/hybris-boot.img

# Temporarily move the rootfs into the updater directory
mv $GEN_IMG_BASE.tar.bz2 updater/$DST_IMG

# Update updater-script with image details.
sed -i -e "s %VERSION% $VERSION_ID g" -e "s %IMAGE_FILE% $DST_IMG g" -e "s %IMAGE_SIZE% $IMG_SIZE g" updater/META-INF/com/google/android/updater-script

# pack updater .zip
pushd updater
zip -r ../$DST_IMG_BASE.zip META-INF/com/google/android/update-binary META-INF/com/google/android/updater-script updater-unpack.sh hybris-boot.img $DST_IMG_BASE.ks $DST_IMG
popd # updater

# Move the rootfs back out of the updater directory
mv updater/$DST_IMG $GEN_IMG_BASE.tar.bz2

# Clean up updater .zip working directory.
rm -rf updater

popd # $IMG_OUT_DIR
### end hybris
%end
