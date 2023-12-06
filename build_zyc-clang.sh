#!/bin/bash
# 
# Compile script for kernel
# Copyright (C) 2023 Jaison Palacio <jaisondpalacio@gmail.com>
#

SECONDS=0
TC_DIR="$HOME/tc/zyc"
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
  echo -e "\n\e[1;93m[*] ZYC clang not found! Setting up ZYC clang in $TC_DIR... \e[0m"
  mkdir -p "$TC_DIR"
  cd "$TC_DIR" || exit 1

  wget -q $(curl -k https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-link.txt 2>/dev/null) -O "zyc-clang.tar.gz"
  tar -xf zyc-clang.tar.gz 
  export PATH="$TC_DIR/bin:$PATH"
  rm -f zyc-clang.tar.gz

  if [ $? -eq 0 ]; then
    echo -e "\n\e[1;93m[*] ZYC clang successfully set up in $TC_DIR \e[0m"
  else
    echo -e "\n\e[1;93m[✗] Setting up ZYC clang! Aborting... \e[0m"
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

wget https://raw.githubusercontent.com/jaisondp/kernel_build/master/upload-script.sh

bash upload-script.sh $ZIPNAME_UNSIGNED
bash upload-script.sh $ZIPNAME_SIGNED

echo -e "\n\e[1;32m[✓] Completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !  \e[0m"
echo -e "\n\e[1;32m[*] Zip: $ZIPNAME_SIGNED \e[0m"