#!/bin/sh

set -e

# ccgo only seems to work under linux/amd64 environment, so we use a container to simulate it.
docker_golang() { 
	docker run --rm --platform=linux/amd64 -v $(pwd):/work -w /work -e GOBIN=/work/ccgo golang:1.23 $*
}

install_ccgo() {
	echo "Installing modernc.org/ccgo/v4..."
	mkdir -p ccgo
	docker_golang go install modernc.org/ccgo/v4@latest
}

gen_cc() {
	echo "Building $1/$2..."
	TARGET_OS="$1"
	TARGET_ARCH="$2"
	OUT="cc/sqlite3_binding_${TARGET_OS}_${TARGET_ARCH}.go"
	docker_golang /work/ccgo/ccgo \
		--package-name cc \
		--prefix-enumerator=_ \
		--prefix-external=X \
		--prefix-field=F \
		--prefix-static-internal=_ \
		--prefix-static-none=_ \
		--prefix-tagged-enum=_ \
		--prefix-tagged-struct=T \
		--prefix-tagged-union=T \
		--prefix-typename=T \
		--prefix-undefined=_ \
		-ignore-unsupported-alignment \
		-DLONGDOUBLE_TYPE=double \
		-DNDEBUG \
		-DSQLITE_THREADSAFE=1 \
		-DSQLITE_ENABLE_RTREE \
		-DHAVE_USLEEP=1 \
		-DSQLITE_ENABLE_FTS3 \
		-DSQLITE_ENABLE_FTS3_PARENTHESIS \
		-DSQLITE_OMIT_DEPRECATED \
		-DSQLITE_DEFAULT_WAL_SYNCHRONOUS=1 \
		-DSQLITE_ENABLE_UPDATE_DELETE_LIMIT=1 \
		-DSQLITE_WITHOUT_ZONEMALLOC \
		-Dpread64=pread \
		-Dpwrite64=pwrite \
		-extended-errors \
		-eval-all-macros \
		-o "$OUT" sqlite3-binding.c

	# We do post-processing here, because we need to hide internal types
	# It's not enough to just replace "T" with "t" in the ccgo command above. We
	# need to check for the final prefix: "T__abc" is a tagged C type, but is
	# static/internal, while "T_abc" is a public one.
	gsed -i 's/\<T__\([a-zA-Z0-9][a-zA-Z0-9_]\+\)/t__\1/g' "$OUT"
}

install_ccgo

gen_cc linux amd64
gen_cc linux arm64
gen_cc linux s390x	
gen_cc darwin amd64
gen_cc darwin amd64
gen_cc windows amd64
