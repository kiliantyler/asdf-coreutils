#!/usr/bin/env bash

set -euo pipefail
GNU_TOOL="coreutils"
GNU_FTP=https://ftp.gnu.org/gnu
GNU_KEYRING=$GNU_FTP/gnu-keyring.gpg
TOOL_NAME="coreutils"
TOOL_TEST="coreutils --help"

MAKE_CHECK_SIGNATURES="${MAKE_CHECK_SIGNATURES:-strict}"
MAKE_PRINT_BUILD_LOG="${MAKE_PRINT_BUILD_LOG:-no}"
MAKE_BUILD_OPTIONS="${MAKE_BUILD_OPTIONS:---with-guile=no}"

fail() {
	echo -e "asdf-$TOOL_NAME: $*"
	exit 1
}

curl_opts=(-fsSL)

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_gnu_releases() {
	while read -r line; do
		if [[ "$line" =~ ${GNU_TOOL}-([1-9]+\.[0-9]+(:?\.[0-9]+)*)\.tar\.gz\.sig ]]; then
			echo "${BASH_REMATCH[1]}"
		fi
	done < <(curl "${curl_opts[@]}" ${GNU_FTP}/${GNU_TOOL}/) | uniq
}

list_all_versions() {
	list_gnu_releases
}

latest_version() {
	list_all_versions | sort_versions | tail -n 1
}

check_installed() {
	command -v "$1" >/dev/null
}

check_colors() {
	[ -n "${NO_COLOR}" ] && return 1                        # NO_COLOR is set
	[ -n "${FORCE_COLOR}" ] && return 0                     # FORCE_COLOR is set
	[ -n "${TERM}" ] && [ "${TERM}" != "dumb" ] && return 0 # TERM is set to a non-dumb value
	return 1
}

print_tools_installed() {
	local program_list=("$@")
	echo "$TOOL_NAME $version installation was successful!"
	if check_installed column; then
		print_table "${program_list[@]}"
	else
		local print_list=("$(awk '{gsub(" ",", "); print }' <<<"${program_list[@]}")")
		echo "Programs installed: ${print_list[*]}"
	fi
}

print_table() {
	local values=("$@")
	if check_colors; then
		green="\033[0;32m"
		reset="\033[0m"
	else
		green=""
		reset=""
	fi
	printf "%sPrograms installed:%s\n" "${green}" "${reset}"
	for value in "${values[@]}"; do
		printf "%-8s\n" "${value}"
	done | column
}

download_release() {
	local version filename url sig_url gnu_keyring gpg_command detail
	version="$1"
	filename="$2"

	url="${GNU_FTP}/${GNU_TOOL}/${GNU_TOOL}-${version}.tar.gz"
	sig_url="${GNU_FTP}/${GNU_TOOL}/${GNU_TOOL}-${version}.tar.gz.sig"
	gnu_keyring=$(dirname "$filename")/gnu-keyring.gpg

	gpg_command="$(command -v gpg gpg2 | head -n 1 || :)"

	if [ -z "${gpg_command}" ]; then
		fail 'gpg or gpg2 command not found. You must install GnuPG'
	fi

	echo "* Downloading $TOOL_NAME release $version..."
	curl "${curl_opts[@]}" -o "$filename" "$url" || fail "Could not download $url"
	curl "${curl_opts[@]}" -o "$filename.sig" "$sig_url" || fail "Could not download signature $sig_url"

	if [[ "${MAKE_CHECK_SIGNATURES}" == "strict" ]]; then
		curl "${curl_opts[@]}" -o "$gnu_keyring" "$GNU_KEYRING" || fail "Could not download gpg key $gnu_keyring"
		if ! detail=$(${gpg_command} --keyring "$gnu_keyring" --verify "$filename.sig"); then
			fail "Failed to GPG verification:\n$detail"
		fi
	fi
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="$3"
	local install_log="$ASDF_DOWNLOAD_PATH/install.log"
	local -a coreutils_programs

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	(
		mkdir -p "$install_path"
		cd "$ASDF_DOWNLOAD_PATH"

		patch_source "$version"

		echo "* Installing $TOOL_NAME release $version..."
		{
			# shellcheck disable=SC2086
			./configure -C --prefix="$install_path" ${MAKE_BUILD_OPTIONS}
			coreutils_programs=$(./build-aux/gen-lists-of-programs.sh --list-progs)
			make install
			chmod +x "$install_path/bin/*"
		} &>"$install_log"

		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
		test -x "$install_path/bin/$tool_cmd" || fail "Expected $install_path/bin/$tool_cmd to be executable."

		# validate all coreutils programs are installed
		for program in $coreutils_programs; do
			if [ ! -x "$install_path/bin/$program" ]; then
				fail "Expected $install_path/bin/$program to be executable."
			fi
		done

		print_tools_installed "$coreutils_programs"
	) || (
		rm -rf "$install_path"
		fail "An error ocurred while installing $TOOL_NAME $version. install log is $install_log"
	)
}
