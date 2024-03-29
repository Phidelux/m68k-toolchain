#! /bin/sh

set -ex
set -o pipefail

# Used mirrors.
GNU_MIRROR=${GNU_MIRROR:-ftp://ftp.gnu.org/gnu}
NEWLIB_MIRROR=${NEWLIB_MIRROR:-ftp://sourceware.org/pub}

# Package versions and hashes.
GCC_VERSION=${GCC_VERSION:-6.3.0}
GCC_PACKAGE=gcc-${GCC_VERSION}.tar.bz2
GCC_DOWNLOAD=${GNU_MIRROR}/gcc/gcc-${GCC_VERSION}/${GCC_PACKAGE}
GCC_SHA512=${GCC_SHA512:-234dd9b1bdc9a9c6e352216a7ef4ccadc6c07f156006a59759c5e0e6a69f0abcdc14630eff11e3826dd6ba5933a8faa43043f3d1d62df6bd5ab1e82862f9bf78}

BINUTILS_VERSION=${BINUTILS_VERSION:-2.28}
BINUTILS_PACKAGE=binutils-${BINUTILS_VERSION}.tar.bz2
BINUTILS_DOWNLOAD=${GNU_MIRROR}/binutils/${BINUTILS_PACKAGE}
BINUTILS_SHA512=${BINUTILS_SHA512:-ede2e4e59a800260eea8c14eafbaee94e30abadafd5c419a3370f9f62213cf027d6400a1d4970b6958bd4d220e675dcd483a708107016e7abd5c99d7392ba8fd}

GMP_VERSION=${GMP_VERSION:-6.1.2}
GMP_PACKAGE=gmp-${GMP_VERSION}.tar.xz
GMP_DOWNLOAD=${GNU_MIRROR}/gmp/${GMP_PACKAGE}
GMP_SHA512=${GMP_SHA512:-9f098281c0593b76ee174b722936952671fab1dae353ce3ed436a31fe2bc9d542eca752353f6645b7077c1f395ab4fdd355c58e08e2a801368f1375690eee2c6}

MPC_VERSION=${MPC_VERSION:-1.0.3}
MPC_PACKAGE=mpc-${MPC_VERSION}.tar.gz
MPC_DOWNLOAD=${GNU_MIRROR}/mpc/${MPC_PACKAGE}
MPC_SHA512=${MPC_SHA512:-0028b76df130720c1fad7de937a0d041224806ce5ef76589f19c7b49d956071a683e2f20d154c192a231e69756b19e48208f2889b0c13950ceb7b3cfaf059a43}

MPFR_VERSION=${MPFR_VERSION:-3.1.5}
MPFR_PACKAGE=mpfr-${MPFR_VERSION}.tar.xz
MPFR_DOWNLOAD=${GNU_MIRROR}/mpfr/${MPFR_PACKAGE}
MPFR_SHA512=${MPFR_SHA512:-3643469b9099b31e41d6ec9158196cd1c30894030c8864ee5b1b1e91b488bccbf7c263c951b03fe9f4ae6f9d29279e157a7dfed0885467d875f107a3d964f032}

NEWLIB_VERSION=${NEWLIB_VERSION:-2.5.0}
NEWLIB_PACKAGE=newlib-${NEWLIB_VERSION}.tar.gz
NEWLIB_DOWNLOAD=${NEWLIB_MIRROR}/newlib/${NEWLIB_PACKAGE}
NEWLIB_SHA512=${NEWLIB_SHA512:-4c99e8dfcb4a7ad0769b9e173ff06628d82e4993ef87d3adf9d6b5578626b14de81b4b3c5f0673ddbb49dc9f3d3628f9f8d4432dcded91f5cd3d27b7d44343cd}

GDB_VERSION=${GDB_VERSION:-7.12.1}
GDB_PACKAGE=gdb-${GDB_VERSION}.tar.xz
GDB_DOWNLOAD=${GNU_MIRROR}/gdb/${GDB_PACKAGE}
GDB_SHA512=${GDB_SHA512:-0ac8d0a495103611ef41167a08313a010dce6ca4c6d827cbe8558a0c1a1a8a6bfa53f1b7704251289cababbfaaf9e075550cdf741a54d6cd9ca3433d910efcd8}

# Toolchain specific configuration.
TOOLCHAIN_PREFIX=/opt/m68k
TOOLCHAIN_WORK_DIR=/tmp/m68k-toolchain-build
TOOLCHAIN_SOURCE_DIR=${TOOLCHAIN_WORK_DIR}/sources
TOOLCHAIN_BUILD_DIR=${TOOLCHAIN_WORK_DIR}/build
TOOLCHAIN_LOG_DIR=${TOOLCHAIN_WORK_DIR}/log

# TOOLCHAIN_HOST=$(echo "${MACHTYPE}" | sed "s/-[^-]*/-cross/")
# TOOLCHAIN_BUILD=${TOOLCHAIN_HOST}
TOOLCHAIN_TARGET=m68k-elf

# TOOLCHAIN_CFLAGS="-O2 -pipe -fPIC"

download() {
	url=$1
	checksum=$2
	hashmethod=$3
	file=$4

	if [ -f "${TOOLCHAIN_SOURCE_DIR}/${file}" ]; then
		calculated_checksum=$(${hashmethod} "${TOOLCHAIN_SOURCE_DIR}/${file}" | cut -f 1 -d " ")

		if echo "${calculated_checksum}" | grep -F -q -w "${checksum}"; then
			echo "Skipping download of ${file} ..."
			return
		fi
	fi

	echo "Downloading ${file} ..."

	curl -s -L -o "${TOOLCHAIN_SOURCE_DIR}/${file}" "${url}" > /dev/null

	calculated_checksum=$(${hashmethod} "${TOOLCHAIN_SOURCE_DIR}/${file}" | cut -f 1 -d " ")
	if ! echo "${calculated_checksum}" | grep -F -q -w "${checksum}"; then
		echo "Failed to download ${file} (${checksum}) ..."
		exit 1
	fi
}

extract() {
	file=$1
	target=$(readlink -f "$2")

	if ! [ -f "${file}" ]; then
		echo "extract: '${file}' does not exist"
		exit 1
	fi

	filename=$(echo basename "${file}" | awk '{print tolower($0)}')

	cd "${target}"
	case "$filename" in
		*.tar.bz2)   tar xjf "${file}"    ;;
		*.tar.gz)    tar xzf "${file}"    ;;
		*.tar.xz)    tar xJf "${file}"    ;;
		*.lzma)      unlzma "${file}"     ;;
		*.bz2)       bunzip2 "${file}"    ;;
		*.rar)       unrar x -ad "${file}";;
		*.gz)        gunzip "${file}"     ;;
		*.tar)       tar xf "${file}"     ;;
		*.tbz2)      tar xjf "${file}"    ;;
		*.tgz)       tar xzf "${file}"    ;;
		*.zip)       unzip "${file}"      ;;
		*.Z)         uncompress "${file}" ;;
		*.7z)        7z x "${file}"       ;;
		*.xz)        unxz "${file}"       ;;
		*)
			echo "extract: '${file}' - unknown archive method"
			exit 1
			;;
	esac
	cd -
}

downloadExtract() {
	url=$1
	checksum=$2
	hashmethod=$3
	file=$4

	if [ -z "${file}" ]; then
		file="${url##*/}"
		file="${file%%\?*}"
	fi

	if [ -z "${hashmethod}" ]; then
		hashmethod='sha512sum'
	fi

	download "${url}" "${checksum}" "${hashmethod}" "${file}"
	extract "${TOOLCHAIN_SOURCE_DIR}/${file}" "${TOOLCHAIN_BUILD_DIR}"
}

finish() {
	echo "Done."
}

trap finish EXIT

# Prepare the build environment.
mkdir -p ${TOOLCHAIN_SOURCE_DIR} \
	${TOOLCHAIN_BUILD_DIR} \
	${TOOLCHAIN_LOG_DIR}

# Download and verify sources.
downloadExtract "${BINUTILS_DOWNLOAD}" "${BINUTILS_SHA512}"
downloadExtract "${GCC_DOWNLOAD}" "${GCC_SHA512}"
downloadExtract "${GMP_DOWNLOAD}" "${GMP_SHA512}"
downloadExtract "${MPC_DOWNLOAD}" "${MPC_SHA512}"
downloadExtract "${MPFR_DOWNLOAD}" "${MPFR_SHA512}"
downloadExtract "${NEWLIB_DOWNLOAD}" "${NEWLIB_SHA512}"
downloadExtract "${GDB_DOWNLOAD}" "${GDB_SHA512}"

# Build binutils
cd "${TOOLCHAIN_BUILD_DIR}/binutils-${BINUTILS_VERSION}"

mkdir build
cd build

../configure \
	--target=${TOOLCHAIN_TARGET} \
	--prefix=${TOOLCHAIN_PREFIX}

make
sudo make install

# Move gmp, mpc and mpfr to gcc directoy.
mv "${TOOLCHAIN_BUILD_DIR}/gmp-${GMP_VERSION}" \
	"${TOOLCHAIN_BUILD_DIR}/gcc-${GCC_VERSION}/gmp"
mv "${TOOLCHAIN_BUILD_DIR}/mpc-${MPC_VERSION}" \
	"${TOOLCHAIN_BUILD_DIR}/gcc-${GCC_VERSION}/mpc"
mv "${TOOLCHAIN_BUILD_DIR}/mpfr-${MPFR_VERSION}" \
	"${TOOLCHAIN_BUILD_DIR}/gcc-${GCC_VERSION}/mpfr"

# Build gcc.
cd "${TOOLCHAIN_BUILD_DIR}/gcc-${GCC_VERSION}"

mkdir build
cd build

../configure \
	--target=${TOOLCHAIN_TARGET} \
	--prefix=${TOOLCHAIN_PREFIX} \
	--enable-languages=c \
	--with-newlib \
	--disable-libmudflap \
	--disable-libssp \
	--disable-libgomp \
	--disable-libstdcxx-pch \
	--disable-threads \
	--with-gnu-as \
	--with-gnu-ld \
	--disable-nls \
	--with-headers=yes \
	--disable-checking \
	--without-headers

make -j6
sudo make install

sudo ln -s ${TOOLCHAIN_TARGET}-gcc-${GCC_VERSION} \
	${TOOLCHAIN_PREFIX}/bin/${TOOLCHAIN_TARGET}-cc

# Export path to target compiler.
export PATH=$PATH:${TOOLCHAIN_PREFIX}/bin/

# Build newlib.
cd "${TOOLCHAIN_BUILD_DIR}/newlib-${NEWLIB_VERSION}"

mkdir build
cd build

../configure \
	--target=${TOOLCHAIN_TARGET} \
	--prefix=${TOOLCHAIN_PREFIX} \
	--enable-newlib-reent-small \
	--disable-malloc-debugging \
	--enable-newlib-multithread \
	--disable-newlib-io-float \
	--disable-newlib-supplied-syscalls \
	--disable-newlib-io-c99-formats \
	--disable-newlib-mb \
	--disable-newlib-atexit-alloc \
	--enable-target-optspace \
	--disable-shared \
	--enable-static \
	--enable-fast-install

make -j6
sudo make install

# Build gdb.
cd "${TOOLCHAIN_BUILD_DIR}/gdb-${GDB_VERSION}"

mkdir build
cd build

../configure \
	--target=${TOOLCHAIN_TARGET} \
	--prefix=${TOOLCHAIN_PREFIX}

make -j6
sudo make install
