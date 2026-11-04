#!/usr/bin/env bash
# Points Grazia's Supabase auth mailer at Resend SMTP. The Resend key is read from the clipboard and never printed.
#   1. resend.com > API Keys > Create: Sending access, domain ragspro.com > Copy
#   2. bash tool/set_supabase_smtp.sh
# Sender switches to noreply@graziastones.com once that domain is verified in Resend: SENDER=noreply@graziastones.com bash ...
set -euo pipefail
REF=jrrmjtbauimrrxwjvmzh
SENDER="${SENDER:-noreply@ragspro.com}"
KEY="$(pbpaste 2>/dev/null | tr -d '[:space:]')"
if [[ "$KEY" != re_* && -t 0 ]]; then read -rsp "Paste the Resend key (hidden), then Enter: " KEY; echo; KEY="$(echo "$KEY" | tr -d '[:space:]')"; fi
[[ "$KEY" == re_* ]] || { echo "No Resend key (re_...) in the clipboard or typed. Copy it first."; exit 1; }
TOK="$(security find-generic-password -s 'Supabase CLI' -w | sed 's/^go-keyring-base64://')"
[[ "$TOK" == sbp_* ]] || TOK="$(echo "$TOK" | base64 -d)"

BODY='<div style="background:#0f0d0b;padding:32px 16px;font-family:Helvetica,Arial,sans-serif"><div style="max-width:480px;margin:0 auto;background:#1a1714;border:1px solid #3a3128;border-radius:16px;padding:32px"><p style="margin:0 0 4px;color:#d6b26a;letter-spacing:4px;font-size:12px">GRAZIA STONES</p><h1 style="margin:0 0 16px;color:#f6efe2;font-family:Georgia,serif;font-weight:normal;font-size:26px">%TITLE%</h1><p style="color:#cfc6b8;font-size:15px;line-height:1.6">%TEXT%</p><p style="margin:28px 0"><a href="{{ .ConfirmationURL }}" style="background:#d6b26a;color:#111;text-decoration:none;padding:14px 26px;border-radius:12px;font-weight:bold;display:inline-block">%BUTTON%</a></p><p style="color:#8a8174;font-size:12px;line-height:1.6">%FOOT%</p></div></div>'

# The key goes through a pipe and the token through a header file descriptor: neither touches disk or `ps`.
umask 077
RESP="$(mktemp)"; trap 'rm -f "$RESP"' EXIT
CODE=$(KEY="$KEY" SENDER="$SENDER" BODY="$BODY" python3 - <<'PY' | curl -s -o "$RESP" -w '%{http_code}' -X PATCH \
  -H @<(printf 'Authorization: Bearer %s\n' "$TOK") -H 'Content-Type: application/json' \
  --data @- "https://api.supabase.com/v1/projects/$REF/config/auth"

import json, os
b = os.environ['BODY']
def t(title, text, button, foot):
    return b.replace('%TITLE%', title).replace('%TEXT%', text).replace('%BUTTON%', button).replace('%FOOT%', foot)
print(json.dumps({
    "smtp_host": "smtp.resend.com", "smtp_port": "465", "smtp_user": "resend", "smtp_pass": os.environ['KEY'],
    "smtp_admin_email": os.environ['SENDER'], "smtp_sender_name": "Grazia Stones", "smtp_max_frequency": 60,
    "rate_limit_email_sent": 30,
    "mailer_subjects_confirmation": "Confirm your Grazia Stones account",
    "mailer_templates_confirmation_content": t("Welcome to Grazia", "Tap the button below to confirm your email and open the app.",
        "Confirm my email", "If you did not create a Grazia Stones account, ignore this email."),
    "mailer_subjects_recovery": "Reset your Grazia Stones password",
    "mailer_templates_recovery_content": t("Reset your password", "Tap the button below to choose a new password.",
        "Set a new password", "If you did not ask for this, ignore this email."),
}))
PY
)
python3 -c "
import json,sys; d=json.load(open(sys.argv[1]))
print('HTTP', sys.argv[2], {k: d.get(k) for k in ['smtp_host','smtp_admin_email','smtp_sender_name','rate_limit_email_sent','mailer_autoconfirm']} if sys.argv[2]=='200' else d)" \
  "$RESP" "$CODE"
