#!/bin/bash

# APKFILE=app-release-unsigned.apk
APKFILE=app-debug.apk
CMP="diff --quiet remotes/origin/HEAD"
MAGISKVER='11'
MAGISKMANVER='4.0'
suffix="$(date +%y%m%d)"

function signapp() {
	echo -e -n "Signing  MagiskManager-v${MAGISKMANVER}-${suffix}.apk...	"
	if [ -f MagiskManager/app/build/outputs/apk/${APKFILE} ]; then
		java -jar Java/signapk.jar MagiskManager/app/src/main/assets/public.certificate.x509.pem MagiskManager/app/src/main/assets/private.key.pk8 MagiskManager/app/build/outputs/apk/${APKFILE} MagiskManager-v${MAGISKMANVER}-${suffix}.apk
		rm -f MagiskManager/app/build/outputs/apk/${APKFILE}
		echo "Done!"
	else
		echo "FAIL!"
	fi
}

function editfiles() { ( sed -i '' "s/versionName \".*\"/versionName \"$MAGISKMANVER-$suffix\"/" MagiskManager/app/build.gradle && sed  -i '' "s/showthread.php?t=3432382/showthread.php?t=3521901/" MagiskManager/app/src/main/java/com/topjohnwu/magisk/AboutActivity.java ) && return 0 || return 1; }

start=$(date +%s.%N)

case $1 in
	cleanup)
		git -C Magisk reset --hard HEAD >/dev/null 2>&1
		git -C MagiskManager reset --hard HEAD >/dev/null 2>&1
		;;
	setup)
#		(cd Magisk; git submodule init; git submodule update;)
#		(cd MagiskManager; git submodule init; git submodule update;)
		rm -rf Magisk >/dev/null 2>&1
		git clone --recursive -j8 git@github.com:topjohnwu/Magisk.git
		rm -rf MagiskManager >/dev/null 2>&1
		git clone git@github.com:topjohnwu/MagiskManager.git
		;;
	sign)
		signapp;;
	*)
		git -C Magisk fetch
		if ! git -C Magisk ${CMP} || [ -n "$1" ]; then
			[ -z "$1" ] && { echo "Magisk:		new commits found!"; git -C Magisk pull --recurse-submodules; }
			git -C Magisk submodule update --remote jni/su
#			git -C Magisk submodule update --recursive --remote
			echo -e -n "Building Magisk-v${MAGISKVER}-${suffix}.zip...		"
			(cd Magisk; ./build.sh all ${MAGISKVER}-${suffix} >/dev/null 2>&1;)
			[ -f Magisk/Magisk-v${MAGISKVER}-${suffix}.zip ] && { echo "Done!"; mv Magisk/Magisk-v${MAGISKVER}-${suffix}.zip .; } || echo "FAIL!"
			updates=1
		else
			echo "Magisk:		no new commits!"
		fi
		git -C MagiskManager fetch
		if ! git -C MagiskManager ${CMP} || [ -n "$1" ]; then
			[ -z "$1" ] && { echo "MagiskManager:	new commits found!"; git -C MagiskManager pull --recurse-submodules; }
			echo -e -n "Editing  MagiskManager/app/build.gradle...	" && editfiles && echo "Done!" || echo "FAIL!"
			echo -e -n "Building MagiskManager-v${MAGISKMANVER}-${suffix}.apk...	"
			(cd MagiskManager; ./gradlew clean >/dev/null 2>&1; ./gradlew init >/dev/null 2>&1; ./gradlew build -x lint -Dorg.gradle.daemon=false >/dev/null 2>&1;)
			[ -f MagiskManager/app/build/outputs/apk/${APKFILE} ] && { echo "Done!"; signapp; } || echo "FAIL!"
			git -C MagiskManager reset --hard HEAD >/dev/null 2>&1
			updates=1
		else
			echo "MagiskManager:	no new commits!"
		fi
		if [ -n "$updates" ]; then
			echo -e -n "Pushing new files to github.com/stangri...	" && git add . && git commit -m "$suffix build" >/dev/null 2>&1 && git push origin >/dev/null 2>&1 && echo "Done!" || echo "FAIL!"
		fi
		;;
esac

end=`date +%s.%N`; runtime=$(echo "${end%.N} - ${start%.N}" | bc -l); secs=$(printf %.f $runtime);
echo -e -n "Total running time: $(printf '%02dh:%02dm:%02ds\n\n' $(($secs/3600)) $(($secs%3600/60)) $(($secs%60)))"
