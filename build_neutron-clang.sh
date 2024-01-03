#!/bin/bash
# 
# Compile script for kernel
# Copyright (C) 2023 Jaison Palacio <jaisondpalacio@gmail.com>
# 

SECONDS=0
TC_DIR="$HOME/tc/neutron"
AK3_DIR="$HOME/AnyKernel3"
KSU_DIR="$HOME/KernelSU"
DEFCONFIG="merlin_defconfig"
WORKSPACE="$(pwd)"

ZIPNAME_UNSIGNED="Sapphire-merlinx-$(date '+%Y%m%d')-unsigned.zip"
ZIPNAME_SIGNED="Sapphire-merlinx-$(date '+%Y%m%d').zip"

MAKE_PARAMS=" \
	O=out \
	ARCH=arm64 \
	CC=clang \
	CROSS_COMPILE=aarch64-linux-gnu- \
	CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
	LLVM=1 \
	LD=ld.lld \
	AS=llvm-as \
	AR=llvm-ar \
	NM=llvm-nm \
	OBJCOPY=llvm-objcopy \
	OBJDUMP=llvm-objdump \
	STRIP=llvm-strip \
	CONFIG_NO_ERROR_ON_MISMATCH=y"

if ! [ -d "$TC_DIR" ]; then
  echo -e "\n\e[1;93m[*] Neutron Toolchains not found! Setting up Neutron Toolchains in $TC_DIR... \e[0m"
  mkdir -p "$TC_DIR"
  cd "$TC_DIR" || exit 1

  curl -LO "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman"
  chmod +x antman
  ./antman -S
  ./antman --patch=glibc
  export PATH="$TC_DIR/bin:$PATH"
	
  if [ $? -eq 0 ]; then
    echo -e "\n\e[1;93m[*] Neutron Toolchains successfully set up in $TC_DIR \e[0m"
  else
    echo -e "\n\e[1;93m[✗] Setting up Neutron Toolchains failed! Aborting... \e[0m"
    exit 1
  fi

	cd "$WORKSPACE"
fi

if [ ! -d "$KSU_DIR" ]; then
  echo -e "\n\e[1;93m[*] KernelSU directory not found! Configuring KernelSU... \e[0m"
  curl -LSsk "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -
  sed -i "s/CONFIG_KSU=n/CONFIG_KSU=y/g" arch/arm64/configs/$DEFCONFIG

  git submodule update --init
  cd KernelSU
  git pull origin main
  cd ..

  if grep -q "CONFIG_KSU=y" arch/arm64/configs/$DEFCONFIG; then
    echo -e "\n\e[1;93m[*] KernelSU successfully configured \e[0m"
  else
    echo -e "\n\e[1;93m[✗] Configuration check failed, KernelSU might not be properly configured... \e[0m"
  fi
fi

export KBUILD_BUILD_USER="Jaison"
export KBUILD_BUILD_HOST="$(source /etc/os-release && echo "${NAME}")"

echo 'CONFIG_OVERLAY_FS=y' >> arch/arm64/configs/merlin_defconfig 
echo 'CONFIG_SCHED_CASS=y' >> arch/arm64/configs/merlin_defconfig

mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG savedefconfig
cp out/defconfig arch/arm64/configs/$DEFCONFIG

echo -e "\n\e[1;93m[*] Starting compilation... \e[0m"
make -j$(nproc --all) $MAKE_PARAMS || exit $?

kernel="out/arch/arm64/boot/Image.gz-dtb"

if [ ! -f "$kernel" ]; then
	echo -e "\n\e[1;32m[✗] Compilation failed! \e[0m"
	exit 1
fi

echo -e "\n\e[1;32m[✓] Kernel compiled succesfully! \e[0m"

if [ -d "$AK3_DIR" ]; then
	cp -r $AK3_DIR AnyKernel3
	git -C AnyKernel3 checkout merlinx &> /dev/null
elif ! git clone -q https://github.com/jaisondp/AnyKernel3.git; then
	echo -e "\n\e[1;93m[*] AnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting... \e[0m"
	exit 1
fi

echo -e "\n\e[1;32m[*] Create a flashable zip! \e[0m"

cp $kernel AnyKernel3
cd AnyKernel3
zip -r9 "$ZIPNAME_UNSIGNED" * -x .git README.md *placeholder
curl -sLo zipsigner-3.0.jar https://github.com/Magisk-Modules-Repo/zipsigner/raw/master/bin/zipsigner-3.0-dexed.jar
java -jar zipsigner-3.0.jar "$ZIPNAME_UNSIGNED" "$ZIPNAME_SIGNED"
echo -e "\n\e[1;32m[✓] Create flashable kernel completed! \e[0m"

echo -e "\n\e[1;32m[✓] Uploading file to mirror! \e[0m"
wget https://raw.githubusercontent.com/jaisondp/kernel_build/master/upload-script.sh 
bash upload-script.sh $ZIPNAME_SIGNED
rm $ZIPNAME_UNSIGNED

echo -e "\n\e[1;32m[✓] Completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !  \e[0m"
echo -e "\n\e[1;32m[*] Zip: $ZIPNAME_SIGNED \e[0m"