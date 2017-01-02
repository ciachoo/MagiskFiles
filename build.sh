#!/bin/bash

# APKFILE=app-release-unsigned.apk
APKFILE=app-debug.apk
CMP="diff --quiet remotes/origin/HEAD"

suffix="$(date +%y%m%d)"

function setup() {
rm -rf Magisk
git clone --recursive -j8 git@github.com:topjohnwu/Magisk.git
rm -rf MagiskManager
git clone git@github.com:topjohnwu/MagiskManager.git
}

function signapp() {
	echo -e -n "Signing  MagiskManager-v3.0-${suffix}.apk...	"
	if [ -f MagiskManager/app/build/outputs/apk/${APKFILE} ]; then
		java -jar Files/Java/signapk.jar MagiskManager/app/src/main/assets/public.certificate.x509.pem MagiskManager/app/src/main/assets/private.key.pk8 MagiskManager/app/build/outputs/apk/${APKFILE} MagiskManager-v3.0-${suffix}.apk
		rm -f MagiskManager/app/build/outputs/apk/${APKFILE}
		echo "Done!"
	else
		echo "FAIL!"
	fi
}

function editfiles() {
	return $(sed -i '' "s/versionName \".*\"/versionName \"3.0-$suffix\"/" MagiskManager/app/build.gradle && \
		sed  -i '' "s/showthread.php?t=3432382/showthread.php?t=3521901/" MagiskManager/app/src/main/java/com/topjohnwu/magisk/AboutActivity.java)
}

if [ "$1" = "sign" ]; then
	signapp
else
	if ! git -C Magisk ${CMP} || [ -n "$1" ]; then
		[ -z "$1" ] && { echo "Magisk:		new commits found!"; git -C Magisk pull --recurse-submodules; }
		echo -e -n "Building Magisk-v10-${suffix}.zip...		"
		cd Magisk; ./build.sh all 10-${suffix} >/dev/null 2>&1; cd ..;
		[ -f Magisk/Magisk-v10-${suffix}.zip ] && { echo "Done!"; mv Magisk/Magisk-v10-${suffix}.zip .; } || echo "FAIL!"
		updates=1
	else
		echo "Magisk:		no new commits!"
	fi

	git -C MagiskManager reset --hard HEAD >/dev/null 2>&1
	if ! git -C MagiskManager ${CMP} || [ -n "$1" ]; then
		[ -z "$1" ] && { echo "MagiskManager:	new commits found!"; git -C MagiskManager pull --recurse-submodules; }
		echo -e -n "Editing  MagiskManager/app/build.gradle...	" && (editfiles) && echo "Done!" || echo "FAIL!"
		echo -e -n "Building MagiskManager-v3.0-${suffix}.apk...	"
		cd MagiskManager
		./gradlew clean >/dev/null 2>&1
		./gradlew init >/dev/null 2>&1
		./gradlew build -x lint >/dev/null 2>&1
		cd ..
		[ -f MagiskManager/app/build/outputs/apk/${APKFILE} ] && { echo "Done!"; signapp; } || echo "FAIL!"
		git -C MagiskManager reset --hard HEAD >/dev/null 2>&1
		updates=1
	else
		echo "MagiskManager:	no new commits!"
	fi
fi

mkdir -p Files
mv -f Magisk*.zip Files/ >/dev/null 2>&1
mv -f Magisk*.apk Files/ >/dev/null 2>&1
if [ -n "$updates" ]; then
	echo -e -n "Pushing new files to github.com/stangri...	" && git -C Files add . && git -C Files commit -m "$suffix build" >/dev/null 2>&1 && git -C Files push >/dev/null 2>&1 && echo "Done!" || echo "FAIL!"
fi
