#!/bin/sh
# check-prereqs.sh — probe the environment for create-next-app readiness.
# POSIX sh. macOS and Linux only. Read-only: installs nothing, writes nothing.
#
# Usage: check-prereqs.sh [target-dir]
# Exit:  0 = ready (may have warnings), 1 = blocked, 2 = bad usage.
#
# Override the required Node version with NEXT_MIN_NODE (default 20.9.0,
# which is what Next.js 16 requires; Next.js 15 needs 18.18.0).

MIN_NODE="${NEXT_MIN_NODE:-20.9.0}"
TARGET="${1:-.}"

BLOCKED=0
WARNED=0
SUGGESTIONS=""

have() { command -v "$1" >/dev/null 2>&1; }

row() { printf '  %-18s %-10s %s\n' "$1" "$2" "$3"; }

ok()    { row "$1" "OK" "$2"; }
warn()  { row "$1" "WARN" "$2"; WARNED=$((WARNED + 1)); }
block() { row "$1" "BLOCKED" "$2"; BLOCKED=$((BLOCKED + 1)); }

suggest() { SUGGESTIONS="${SUGGESTIONS}  $1\n"; }

# ver_ge A B -> true if version A >= version B (dotted numeric, 3 parts max)
ver_ge() {
	awk -v a="$1" -v b="$2" '
	BEGIN {
		na = split(a, x, "."); nb = split(b, y, ".")
		for (i = 1; i <= 3; i++) {
			ai = (i <= na) ? x[i] + 0 : 0
			bi = (i <= nb) ? y[i] + 0 : 0
			if (ai > bi) exit 0
			if (ai < bi) exit 1
		}
		exit 0
	}'
}

# ---------------------------------------------------------------- platform ---

OS="$(uname -s 2>/dev/null || echo unknown)"
DISTRO=""
case "$OS" in
Darwin)
	PLATFORM="macos"
	;;
Linux)
	PLATFORM="linux"
	if [ -r /etc/os-release ]; then
		# shellcheck disable=SC1091
		DISTRO="$(. /etc/os-release 2>/dev/null && echo "${ID_LIKE:-$ID}")"
	fi
	;;
*)
	printf 'Unsupported platform: %s. This skill supports macOS and Linux only.\n' "$OS" >&2
	exit 2
	;;
esac

# Which installers are actually available here, best first.
NODE_INSTALLER=""
for c in fnm volta mise asdf; do
	if have "$c"; then NODE_INSTALLER="$c"; break; fi
done
if [ -z "$NODE_INSTALLER" ] && [ -n "${NVM_DIR:-}" ]; then NODE_INSTALLER="nvm"; fi
if [ -z "$NODE_INSTALLER" ]; then
	if [ "$PLATFORM" = macos ]; then
		have brew && NODE_INSTALLER="brew"
	else
		for c in apt-get dnf pacman zypper; do
			if have "$c"; then NODE_INSTALLER="$c"; break; fi
		done
	fi
fi

node_install_cmd() {
	case "$NODE_INSTALLER" in
	fnm) echo "fnm install --lts && fnm use --lts" ;;
	volta) echo "volta install node@lts" ;;
	mise) echo "mise use -g node@lts" ;;
	asdf) echo "asdf plugin add nodejs && asdf install nodejs latest && asdf global nodejs latest" ;;
	nvm) echo "nvm install --lts && nvm use --lts" ;;
	brew) echo "brew install node" ;;
	apt-get) echo "curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt-get install -y nodejs" ;;
	dnf) echo "sudo dnf install -y nodejs" ;;
	pacman) echo "sudo pacman -S --needed nodejs npm" ;;
	zypper) echo "sudo zypper install -y nodejs" ;;
	*)
		if [ "$PLATFORM" = macos ]; then
			echo "install Homebrew (https://brew.sh) then: brew install node  — or fnm: https://github.com/Schniz/fnm"
		else
			echo "install fnm (https://github.com/Schniz/fnm) then: fnm install --lts  — or use your distro's package manager"
		fi
		;;
	esac
}

echo
printf 'Environment (%s%s)\n' "$PLATFORM" "${DISTRO:+/$DISTRO}"
echo

# -------------------------------------------------------------------- node ---

if have node; then
	NODE_VER="$(node --version 2>/dev/null | sed 's/^v//')"
	if [ -n "$NODE_VER" ] && ver_ge "$NODE_VER" "$MIN_NODE"; then
		ok "node" "v$NODE_VER (need >= $MIN_NODE)"
	else
		block "node" "v${NODE_VER:-?} is too old — need >= $MIN_NODE"
		suggest "upgrade Node: $(node_install_cmd)"
	fi
else
	block "node" "not found"
	suggest "install Node: $(node_install_cmd)"
fi

# --------------------------------------------------------- package manager ---

PM=""
PM_LIST=""
for c in npm pnpm yarn bun; do
	if have "$c"; then
		v="$($c --version 2>/dev/null | head -n1)"
		PM_LIST="${PM_LIST}${PM_LIST:+, }$c $v"
		[ -z "$PM" ] && PM="$c"
	fi
done

if [ -n "$PM" ]; then
	ok "package manager" "$PM_LIST"
else
	block "package manager" "none of npm/pnpm/yarn/bun found"
	if have corepack; then
		suggest "enable one via corepack: corepack enable"
	else
		suggest "npm ships with Node — installing Node (above) fixes this"
	fi
fi

have corepack && ok "corepack" "available (can provision pnpm/yarn)"

# --------------------------------------------------------------------- git ---

if have git; then
	GIT_VER="$(git --version 2>/dev/null | awk '{print $3}')"
	GIT_NAME="$(git config --get user.name 2>/dev/null)"
	GIT_EMAIL="$(git config --get user.email 2>/dev/null)"
	if [ -n "$GIT_NAME" ] && [ -n "$GIT_EMAIL" ]; then
		ok "git" "$GIT_VER ($GIT_NAME <$GIT_EMAIL>)"
	else
		warn "git" "$GIT_VER but user.name/user.email unset — the initial commit will fail"
		suggest "git config --global user.name \"Your Name\""
		suggest "git config --global user.email \"you@example.com\""
	fi
else
	warn "git" "not found — create-next-app will skip git init"
	if [ "$PLATFORM" = macos ]; then
		suggest "install git: xcode-select --install  (or: brew install git)"
	else
		suggest "install git with your distro's package manager"
	fi
fi

# ---------------------------------------------------------------- registry ---

REGISTRY="$(npm config get registry 2>/dev/null)"
case "$REGISTRY" in
http*) : ;;
*) REGISTRY="https://registry.npmjs.org/" ;;
esac

if have curl; then
	CODE="$(curl -sS -m 10 -o /dev/null -w '%{http_code}' "$REGISTRY" 2>/dev/null)"
	case "$CODE" in
	2* | 3*) ok "npm registry" "reachable ($REGISTRY)" ;;
	*) block "npm registry" "unreachable ($REGISTRY, HTTP ${CODE:-none}) — check network/proxy/VPN" ;;
	esac
else
	warn "npm registry" "curl not found — could not verify reachability"
fi

# -------------------------------------------------------------- target dir ---

if [ -e "$TARGET" ] && [ ! -d "$TARGET" ]; then
	block "target dir" "$TARGET exists and is not a directory"
elif [ -d "$TARGET" ]; then
	if [ ! -w "$TARGET" ]; then
		block "target dir" "$TARGET is not writable"
	else
		ENTRIES="$(ls -A "$TARGET" 2>/dev/null | wc -l | tr -d ' ')"
		if [ "$ENTRIES" -eq 0 ]; then
			ok "target dir" "$TARGET exists and is empty"
		elif [ -f "$TARGET/package.json" ]; then
			warn "target dir" "$TARGET already contains a package.json — existing project"
		else
			warn "target dir" "$TARGET is not empty ($ENTRIES entries)"
		fi
	fi
else
	PARENT="$(dirname "$TARGET")"
	if [ -d "$PARENT" ] && [ -w "$PARENT" ]; then
		ok "target dir" "$TARGET will be created"
	else
		block "target dir" "cannot create $TARGET — $PARENT is missing or not writable"
	fi
fi

# ---------------------------------------------------------------- capacity ---

DIR_FOR_DF="$TARGET"
[ -d "$DIR_FOR_DF" ] || DIR_FOR_DF="$(dirname "$TARGET")"
AVAIL_KB="$(df -Pk "$DIR_FOR_DF" 2>/dev/null | awk 'NR==2 {print $4}')"
if [ -n "$AVAIL_KB" ]; then
	AVAIL_MB=$((AVAIL_KB / 1024))
	if [ "$AVAIL_MB" -lt 1024 ]; then
		warn "disk space" "${AVAIL_MB}MB free — a Next.js install needs roughly 500MB-1GB"
	else
		ok "disk space" "${AVAIL_MB}MB free"
	fi
fi

# ------------------------------------------------------------------ verdict ---

echo
if [ -n "$SUGGESTIONS" ]; then
	echo "Suggested fixes (NOT run automatically):"
	printf %b "$SUGGESTIONS"
	echo
fi

echo "PLATFORM=$PLATFORM"
echo "PACKAGE_MANAGER=${PM:-none}"
echo "NODE_INSTALLER=${NODE_INSTALLER:-none}"
echo "WARNINGS=$WARNED"
echo "BLOCKERS=$BLOCKED"

if [ "$BLOCKED" -gt 0 ]; then
	echo "RESULT=BLOCKED"
	exit 1
fi
echo "RESULT=READY"
exit 0
