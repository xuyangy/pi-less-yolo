#!/bin/sh
set -e

# Register the runtime UID in /etc/passwd before starting pi.
# SSH calls getpwuid(3) and hard-fails without an entry; nss_wrapper is
# unavailable in Wolfi so we append directly.
#
# HOME is caller-controlled (docker run --env HOME=...), and this writes a
# newline-delimited, colon-delimited record. An unsanitized value containing
# either could append a second, attacker-chosen account (e.g. a passwordless
# UID 0 entry). Reject rather than sanitize: any HOME with those characters is
# malformed regardless of intent.
# A literal newline: command substitution strips trailing newlines, so
# $(printf '\n') would collapse to the empty string and match everything.
_NL='
'
case "${HOME}" in
    *:* | *"${_NL}"*)
        echo "entrypoint: HOME contains an illegal character (':' or newline)" >&2
        exit 1
        ;;
esac
unset _NL

if ! grep -q "^[^:]*:[^:]*:$(id -u):" /etc/passwd; then
    printf 'piuser:x:%d:%d:piuser:%s:/bin/sh\n' \
        "$(id -u)" "$(id -g)" "${HOME}" >> /etc/passwd
fi

# Which agent this image wraps. Set via ENV in each Dockerfile so the two
# images can share one entrypoint rather than duplicating the guards above.
_AGENT="${PI_ENTRY_CMD:-pi}"

# Pass through to a shell when invoked via `<agent>:shell`; otherwise run the agent.
case "${1:-}" in
    bash|sh) exec "$@" ;;
    *) exec "${_AGENT}" "$@" ;;
esac
