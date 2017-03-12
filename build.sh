#!/bin/bash

cd "${0%/*}"
export GIT_EDITOR=true
export GIT_MERGE_AUTOEDIT=no

# APKFILE=app-release-unsigned.apk
APKFILE=app-debug.apk
CMP="diff --quiet --ignore-submodules=dirty @{upstream}"
MAGISKVER='12'
MAGISKMANVER='5.0'
suffix="$(date +%y%m%d)"
[[ "$(uname -a)" =~ "Darwin" ]] && repl_command="sed -i ''" || repl_command="sed -i"

ok() { echo -e '\033[0;32m[\xe2\x9c\x93]\033[0m'; }
fail() { echo -e '\033[0;31m[\xe2\x9c\x97]\033[0m'; }

edit_magiskman_files() { 
$repl_command "s|topjohnwu/MagiskManager|stangri/MagiskFiles/master|" MagiskManager/app/src/main/java/com/topjohnwu/magisk/asyncs/CheckUpdates.java && \
$repl_command "s/versionName \".*\"/versionName \"${MAGISKMANVER}.${suffix}\"/" MagiskManager/app/build.gradle && \
$repl_command "s/showthread.php?t=3432382/showthread.php?t=3521901/" MagiskManager/app/src/main/java/com/topjohnwu/magisk/AboutActivity.java && return 0 || return 1; }


edit_magisk_files() { 
$repl_command "s/.*ps |/\$TOOLPATH\/ps |/" Magisk/zip_static/common/magiskhide/enable && \
$repl_command "s/.*ps |/\$TOOLPATH\/ps |/" Magisk/zip_static/common/magiskhide/disable && \
$repl_command "s|\$\"DUMMDIR|\"\$DUMMDIR|" Magisk/scripts/magic_mask.sh && \
$repl_command "s/sh \$MOD\/\$1.sh.*/sh \$MOD\/\$1.sh \&/" Magisk/scripts/magic_mask.sh && \
$repl_command "s/sh \$SCRIPT.*/sh \$SCRIPT \&/" Magisk/scripts/magic_mask.sh && return 0 || return 1; }

# https://raw.githubusercontent.com/topjohnwu/MagiskManager/updates/magisk_update.json

update_updates() {
if [ -f Magisk-v${MAGISKVER}-${suffix}.zip ]; then
cat << EOF > updates/magisk_update.json
{
  "app": {
    "version": "stub",
    "versionCode": "10",
    "link": "https://github.com/topjohnwu/MagiskManager/releases/download/v3.0/MagiskManager-stub.apk",
    "changelog": "  - Upgrade on Play Store!"
  },
  "magisk": {
    "versionCode": "${suffix}",
    "link": "https://raw.githubusercontent.com/stangri/MagiskFiles/master/Magisk-v${MAGISKVER}-${suffix}.zip",
    "changelog": "Check the link",
    "note": "https://forum.xda-developers.com/showthread.php?t=3521901"
  },
  "uninstall": {
    "filename": "Magisk-uninstaller-20170206.zip",
    "link": "http://tiny.cc/latestuninstaller"
  }
}
EOF
fi

if [ -f MagiskManager-v${MAGISKMANVER}-${suffix}.apk ]; then
cat << EOF > updates/magisk_manager_update.txt
lastest_version=${suffix}
apk_file=MagiskManager-v${MAGISKMANVER}-${suffix}.apk
download_url=https://raw.githubusercontent.com/stangri/MagiskFiles/master/\$apk_file
EOF
fi
}

signapp() {
	echo -e -n "Signing  MagiskManager-v${MAGISKMANVER}-${suffix}.apk...	"
	if [ -f MagiskManager/app/build/outputs/apk/${APKFILE} ]; then
		java -jar Java/signapk.jar MagiskManager/app/src/main/assets/public.certificate.x509.pem MagiskManager/app/src/main/assets/private.key.pk8 MagiskManager/app/build/outputs/apk/${APKFILE} MagiskManager-v${MAGISKMANVER}-${suffix}.apk
		rm -f MagiskManager/app/build/outputs/apk/${APKFILE}
		ok
	else
		fail
	fi
}

checkorigin() {
echo -n "Checking for origin updates...	"; git fetch >/dev/null 2>&1 && ok || fail
if ! git ${CMP}; then 
	echo "Updating local files from origin repository... "
	git pull origin master && git reset --hard HEAD >/dev/null 2>&1 && git push origin master && ok || fail
	echo "Running build.sh again."
	./build.sh
	exit 0
else
	echo "No origin updates found."
fi
}

start=$(date +%s.%N)

case $1 in
	cleanup)
		git -C Magisk reset --hard HEAD >/dev/null 2>&1
		git -C MagiskManager reset --hard HEAD >/dev/null 2>&1
		;;
	setup)
#		(cd Magisk; git submodule init; git submodule update;)
#		(cd MagiskManager; git submodule init; git submodule update;)
		echo -e -n ".DS_Store\nMagisk\nMagiskManager\n" >> .git/info/exclude
		rm -rf Magisk >/dev/null 2>&1
		git clone --recursive -j8 git@github.com:topjohnwu/Magisk.git
		rm -rf MagiskManager >/dev/null 2>&1
		git clone git@github.com:topjohnwu/MagiskManager.git
		;;
	sign)
		signapp;;
	*)

		checkorigin
		echo -n "Checking for upstream Magisk/MagiskManager updates...	"; git -C Magisk fetch >/dev/null 2>&1 && git -C MagiskManager fetch >/dev/null 2>&1 && ok || fail

		if ! git -C Magisk ${CMP} || ! git -C MagiskManager ${CMP}; then 
			echo "Updates found!"; rebuild=1; 
		else
			[ -n "$1" ] && { echo "Forced rebuild!"; rebuild=1; }
		fi

		if [ -n "$rebuild" ]; then
			[ -z "$1" ] && { echo "Magisk:		new commits found!"; git -C Magisk fetch >/dev/null 2>&1; git -C Magisk reset --hard origin/master >/dev/null 2>&1; git -C Magisk pull --recurse-submodules >/dev/null 2>&1; }
#			git -C Magisk submodule update --remote jni/su
#			git -C Magisk submodule update --recursive --remote
			echo -e -n "Editing  Magisk files...	" && edit_magisk_files && ok || fail
			echo -e -n "Building Magisk-v${MAGISKVER}-${suffix}.zip...		"
			(cd Magisk; ./build.sh all ${suffix} >/dev/null 2>&1;)
			[ -f Magisk/Magisk-v${suffix}.zip ] && { ok; mv Magisk/Magisk-v${suffix}.zip Magisk/Magisk-v${MAGISKVER}-${suffix}.zip; mv Magisk/Magisk-v${MAGISKVER}-${suffix}.zip .; } || fail
			git -C Magisk reset --hard HEAD >/dev/null 2>&1
			updates=1
		else
			echo "Magisk:		no new commits!"
		fi
		if [ -n "$rebuild" ]; then
			[ -z "$1" ] && { echo "MagiskManager:	new commits found!"; git -C MagiskManager fetch >/dev/null 2>&1; git -C MagiskManager reset --hard origin/master >/dev/null 2>&1; git -C MagiskManager pull --recurse-submodules >/dev/null 2>&1 ; }
			echo -e -n "Editing  MagiskManager files...	" && edit_magiskman_files && ok || fail
			echo -e -n "Building MagiskManager-v${MAGISKMANVER}-${suffix}.apk...	"
			(cd MagiskManager; ./gradlew clean >/dev/null 2>&1; ./gradlew init >/dev/null 2>&1; ./gradlew build -x lint -Dorg.gradle.daemon=false -Dorg.gradle.java.home=/Library/Java/JavaVirtualMachines/jdk1.8.0_121.jdk/Contents/Home >/dev/null 2>&1;)
			[ -f MagiskManager/app/build/outputs/apk/${APKFILE} ] && { ok; signapp; } || fail
			git -C MagiskManager reset --hard HEAD >/dev/null 2>&1
			updates=1			
#apk_update=1
		else
			echo "MagiskManager:	no new commits!"
		fi

		if [ -n "$updates" ]; then
			echo -e -n "Updating update files...		" && update_updates && ok || fail
			echo -e -n "Pushing new files to github.com/stangri...	"
			git add . && git commit -m "$suffix build" >/dev/null 2>&1 && git push origin >/dev/null 2>&1 && ok || fail
		fi
		;;
esac

end=`date +%s.%N`; runtime=$(echo "${end%.N} - ${start%.N}" | bc -l); secs=$(printf %.f $runtime);
echo -e -n "Total running time: $(printf '%02dh:%02dm:%02ds\n\n' $(($secs/3600)) $(($secs%3600/60)) $(($secs%60)))"
