#!/usr/bin/env bash

set -euo pipefail
GNU_TOOL="coreutils"
GNU_FTP=https://ftp.gnu.org/gnu
GNU_KEYRING=$GNU_FTP/gnu-keyring.gpg
TOOL_NAME="coreutils"
TOOL_TEST="coreutils --help"

MAKE_CHECK_SIGNATURES="${MAKE_CHECK_SIGNATURES:-strict}"
MAKE_PRINT_BUILD_LOG="${MAKE_PRINT_BUILD_LOG:-no}"
ADDITIONAL_BUILD_PROGRAMS="${ADDITIONAL_BUILD_PROGRAMS:-"arch,coreutils,hostname"}"
MAKE_BUILD_OPTIONS="${MAKE_BUILD_OPTIONS:-"--with-guile=no --enable-install-program=${ADDITIONAL_BUILD_PROGRAMS}"}"

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

print_tools() {
	local program_list=("$@")
	if check_installed column; then
		print_table "${program_list[@]}"
	else
		local print_list=("$(awk '{gsub(" ",", "); print }' <<<"${program_list[@]}")")
		echo "${print_list[*]}"
	fi
}

print_table() {
	local values=("$@")
	for value in "${values[@]}"; do
		printf "%-8s\n" "${value}"
	done | column
}

download_release() {
	local version filename url sig_url gnu_keyring gpg_command
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
		# TODO: Fix GPG verification
		# if ! detail=$(${gpg_command} --keyring "$gnu_keyring" --verify "$filename.sig"); then
		# 	fail "Failed to GPG verification:\n$detail"
		# fi
	fi
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="$3"
	local install_log="$ASDF_DOWNLOAD_PATH/install.log"
	local -a no_install_progs build_if_possible_progs default_progs

	(
		mkdir -p "$install_path"
		cd "$ASDF_DOWNLOAD_PATH"

		echo "* Installing $TOOL_NAME release $version..."
		{
			# shellcheck disable=SC2086
			./configure -C --prefix="$install_path" ${MAKE_BUILD_OPTIONS}
			# generate list of programs
			IFS=$'\n'
			for line in $(./build-aux/gen-lists-of-programs.sh --automake); do
				case "$line" in
				no_install__progs*src/*)
					no_install_progs+=("${line#*src/}")
					;;
				build_if_possible__progs*src/*)
					build_if_possible_progs+=("${line#*src/}")
					;;
				default__progs*src/*)
					if [[ "${line#*src/}" == "ginstall" ]]; then
						line=install
					fi
					default_progs+=("${line#*src/}")
					;;
				esac
			done
			if [ "$install_type" != "version" ]; then
				fail "asdf-$TOOL_NAME supports release installs only"
			fi
			make install
			chmod +x "$install_path/bin/*"
		} &>"$install_log"

		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"

		# validate "coreutils" command is installed
		test -x "$install_path/bin/$tool_cmd" || fail "Expected $install_path/bin/$tool_cmd to be executable."
		programs=("${default_progs[@]}")
		local -a not_installed_programs installed_programs programs
		programs=("${default_progs[@]}")

		if [ -n "$ADDITIONAL_BUILD_PROGRAMS" ]; then
			IFS=" " read -r -a programs <<<"$(echo "$ADDITIONAL_BUILD_PROGRAMS" | tr ',' '\n')"
		fi

		# validate the rest of the programs are installed
		for program in "${programs[@]}"; do
			if [ ! -x "$install_path/bin/$program" ]; then
				fail "Expected $install_path/bin/$program to be executable."
			fi
			installed_programs+=("$program")
		done

		# check for "build_if_possible" programs
		for program in "${build_if_possible_progs[@]}"; do
			if [ -x "$install_path/bin/$program" ]; then
				installed_programs+=("$program")
			else
				not_installed_programs+=("$program")
			fi
		done
		echo "$TOOL_NAME $version installation was successful!"
		echo "The following programs were installed:"
		print_tools "${installed_programs[@]}"

		echo "The following programs were not installed:"
		print_tools "${not_installed_programs[@]}"
	) || (
		rm -rf "$install_path"
		fail "An error ocurred while installing $TOOL_NAME $version. install log is $install_log"
	)
}
