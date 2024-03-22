# Copyright 2023-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Autogenerated by pycargoebuild 0.10

EAPI=8

CRATES="
	adler@1.0.2
	ahash@0.8.6
	arrayvec@0.7.4
	autocfg@1.1.0
	bitflags@2.4.1
	bytemuck@1.14.0
	cc@1.0.83
	cfg-if@1.0.0
	crc32fast@1.3.2
	crossbeam-deque@0.8.3
	crossbeam-epoch@0.9.15
	crossbeam-utils@0.8.16
	either@1.9.0
	fallible_collections@0.4.9
	flate2@1.0.28
	hashbrown@0.13.2
	libc@0.2.149
	lodepng@3.9.1
	memoffset@0.9.0
	miniz_oxide@0.7.1
	once_cell@1.18.0
	proc-macro2@1.0.69
	quote@1.0.33
	rayon-core@1.12.0
	rayon@1.8.0
	rgb@0.8.37
	scopeguard@1.2.0
	syn@2.0.38
	thread_local@1.1.7
	unicode-ident@1.0.12
	version_check@0.9.4
	zerocopy-derive@0.7.20
	zerocopy@0.7.20
"

inherit cargo

DESCRIPTION="Palette quantization library that powers pngquant and other PNG optimizers"
HOMEPAGE="https://pngquant.org/lib/"
SRC_URI="https://github.com/ImageOptim/${PN}/archive/${PV}.tar.gz -> ${P}.tar.gz"
SRC_URI+=" ${CARGO_CRATE_URIS}"
S="${WORKDIR}"/${P}/imagequant-sys

LICENSE="GPL-3+"
# Dependent crate licenses
LICENSE+=" MIT Unicode-DFS-2016 ZLIB"
SLOT="0/0"
KEYWORDS="amd64 arm arm64 ~loong ~ppc ~ppc64 ~s390 sparc"

BDEPEND="
	>=dev-util/cargo-c-0.9.11
	>=virtual/rust-1.60
"

QA_FLAGS_IGNORED="usr/lib.*/libimagequant.so.*"

src_compile() {
	local cargoargs=(
		--library-type=cdylib
		--prefix=/usr
		--libdir="/usr/$(get_libdir)"
		$(usev !debug '--release')
	)

	cargo cbuild "${cargoargs[@]}" || die "cargo cbuild failed"
}

src_install() {
	local cargoargs=(
		--library-type=cdylib
		--prefix=/usr
		--libdir="/usr/$(get_libdir)"
		--destdir="${ED}"
		$(usex debug '--debug' '--release')
	)

	cargo cinstall "${cargoargs[@]}" || die "cargo cinstall failed"
}
