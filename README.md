<div align="center">

# asdf-coreutils [![Build](https://github.com/kiliantyler/asdf-coreutils/actions/workflows/build.yml/badge.svg)](https://github.com/kiliantyler/asdf-coreutils/actions/workflows/build.yml) [![Lint](https://github.com/kiliantyler/asdf-coreutils/actions/workflows/lint.yml/badge.svg)](https://github.com/kiliantyler/asdf-coreutils/actions/workflows/lint.yml)

[coreutils](https://www.gnu.org/software/coreutils/) plugin for the [asdf version manager](https://asdf-vm.com).

</div>

# Contents

- [Dependencies](#dependencies)
- [Install](#install)
- [Contributing](#contributing)
- [License](#license)

# Dependencies

**TODO: adapt this section**

- `bash`, `curl`, `tar`, and [POSIX utilities](https://pubs.opengroup.org/onlinepubs/9699919799/idx/utilities.html).
- `SOME_ENV_VAR`: set this environment variable in your shell config to load the correct version of tool x.

# Install

Plugin:

```shell
asdf plugin add coreutils
# or
asdf plugin add coreutils https://github.com/kiliantyler/asdf-coreutils.git
```

coreutils:

```shell
# Show all installable versions
asdf list-all coreutils

# Install specific version
asdf install coreutils latest

# Set a version globally (on your ~/.tool-versions file)
asdf global coreutils latest

# Now coreutils commands are available
coreutils --help
```

Check [asdf](https://github.com/asdf-vm/asdf) readme for more instructions on how to
install & manage versions.

# Contributing

Contributions of any kind welcome! See the [contributing guide](contributing.md).

[Thanks goes to these contributors](https://github.com/kiliantyler/asdf-coreutils/graphs/contributors)!

# License

See [LICENSE](LICENSE) © [Kilian Tyler](https://github.com/kiliantyler/)
