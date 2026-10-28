#!/usr/bin/env bash
set -u
# Ubuntu package paths have changed between releases; check known locations.
for agent in \
    /usr/bin/polkit-mate-authentication-agent-1 \
    /usr/libexec/polkit-mate-authentication-agent-1 \
    /usr/lib/mate-polkit/polkit-mate-authentication-agent-1 \
    /usr/lib/*/mate-polkit/polkit-mate-authentication-agent-1; do
    if [[ -x "$agent" ]]; then
        exec "$agent"
    fi
done
exit 0