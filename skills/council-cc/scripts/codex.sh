#!/usr/bin/env bash
# Council member A: Codex, called file in, file out, so nobody retypes its text.
#
#   codex.sh <dir> <out> <prompt> [file...]
#       Sends <prompt> with the files appended to Codex and writes its answer to <out>.
#       The first call for <dir> starts a Codex session; later calls resume it, so Codex
#       keeps what it read and reasoned. Prompts, logs and the session id live in <dir>/codex/.
#   codex.sh --ready           is everything the council needs from Codex in place?
#                              Prints READY, or one MISSING line per gap.
#   codex.sh --check           try it: start a Codex session and resume it
#   codex.sh --cleanup <dir>   delete the Codex session of <dir>
#
# A call prints one status line and saves it to <dir>/codex/status:
#   OK model=<model> effort=<effort>
#   CODEX_UNAVAILABLE: <reason>

MODEL="${COUNCIL_CODEX_MODEL:-gpt-6.1-sol}"
EFFORT="${COUNCIL_CODEX_EFFORT:-high}"
TIMEOUT="${COUNCIL_CODEX_TIMEOUT:-600}"   # seconds per Codex call
PLUGIN=codex@openai-codex                 # https://github.com/openai/codex-plugin-cc

# Run codex with the given arguments: stdin from $input, stderr to $log, killed after $TIMEOUT.
run() {
  rm -f "$out"
  codex "$@" < "$input" > /dev/null 2> "$log" &
  local pid=$! waited=0
  while kill -0 "$pid" 2> /dev/null; do
    if [ "$waited" -ge "$TIMEOUT" ]; then
      pkill -P "$pid" 2> /dev/null; kill "$pid" 2> /dev/null; wait "$pid" 2> /dev/null
      return 124
    fi
    sleep 2; waited=$((waited + 2))
  done
  wait "$pid"
}

# One Codex turn: resume the council's session, or start one and remember its id.
turn() {
  local model=(-m "$MODEL")
  [ -f "$state/default-model" ] && model=()
  if [ -s "$state/session" ]; then
    run exec resume "${model[@]}" -c model_reasoning_effort="$EFFORT" -c sandbox_mode=read-only \
      --skip-git-repo-check -o "$out" "$(cat "$state/session")" -
  else
    run exec "${model[@]}" -c model_reasoning_effort="$EFFORT" --sandbox read-only \
      --skip-git-repo-check -o "$out" -
    local rc=$?
    sed -n 's/^session id: //p' "$log" | head -n 1 > "$state/session"
    return $rc
  fi
}

forget_session() {
  local sid
  sid=$(cat "$state/session" 2> /dev/null)
  [ -n "$sid" ] && codex delete --force "$sid" > /dev/null 2>&1
  rm -f "$state/session"
}

signin_error() { grep -qiE 'not logged in|codex login|"status": ?401|unauthorized' "$log"; }

call() {
  local dir=$1 prompt=$3 n rc status f
  out=$2
  state="$dir/codex"
  shift 3
  mkdir -p "$state" "$(dirname "$out")"
  n=$(( $(ls "$state" | grep -c '\.in\.md$') + 1 ))
  input="$state/call-$n.in.md"
  log="$state/call-$n.log"
  {
    cat "$prompt"
    for f in "$@"; do
      [ -f "$f" ] || continue
      printf '\n\n===== %s =====\n\n' "$f"
      cat "$f"
    done
  } > "$input"

  turn; rc=$?
  # One retry in a fresh session: the attached files carry everything Codex needs.
  if [ $rc -ne 0 ] && [ $rc -ne 124 ] && ! signin_error; then
    grep -qE 'model_not_found|model is not supported' "$log" && touch "$state/default-model"
    forget_session
    log="$state/call-$n.retry.log"
    turn; rc=$?
  fi

  if [ $rc -eq 0 ] && [ -s "$out" ]; then
    status="OK model=$(sed -n 's/^model: //p' "$log" | head -n 1)"
    status="$status effort=$(sed -n 's/^reasoning effort: //p' "$log" | head -n 1)"
    [ -f "$state/default-model" ] && status="$status ($MODEL unavailable, Codex default model)"
  elif [ $rc -eq 124 ]; then
    status="CODEX_UNAVAILABLE: timeout after ${TIMEOUT}s"
  elif signin_error; then
    status="CODEX_UNAVAILABLE: sign-in required — codex login"
  elif [ $rc -eq 0 ]; then
    status="CODEX_UNAVAILABLE: empty answer"
  else
    status="CODEX_UNAVAILABLE: $( (grep -E 'ERROR|error' "$log" || grep -v '^[[:space:]]*$' "$log") \
      | tail -n 1 | cut -c 1-200)"
  fi
  echo "$status" | tee "$state/status"
  [ "${status%% *}" = OK ]
}

ready() {
  local gaps=0 plugin
  if ! command -v node > /dev/null 2>&1; then
    echo "MISSING: Node.js 18.18 or later"; gaps=1
  elif command -v claude > /dev/null 2>&1; then
    plugin=$(claude plugin list --json 2> /dev/null | node -e '
      let s = "";
      process.stdin.on("data", (d) => (s += d)).on("end", () => {
        let list = [];
        try { list = JSON.parse(s); } catch {}
        const p = (Array.isArray(list) ? list : []).find((x) => x.id === process.argv[1]);
        console.log(!p ? "missing" : p.enabled ? "enabled" : "disabled");
      });' "$PLUGIN")
    case "$plugin" in
      missing) echo "MISSING: the Codex plugin for Claude Code ($PLUGIN) is not installed"; gaps=1 ;;
      disabled) echo "MISSING: the Codex plugin for Claude Code ($PLUGIN) is disabled"; gaps=1 ;;
    esac
  fi
  if ! command -v codex > /dev/null 2>&1; then
    echo "MISSING: the Codex CLI"; gaps=1
  elif ! codex login status > /dev/null 2>&1; then
    echo "MISSING: Codex sign-in"; gaps=1
  fi
  [ $gaps -eq 0 ] && echo READY
  return $gaps
}

check() {
  local d s
  echo "PASS installed: $(codex --version 2>&1 | head -n 1)"
  if codex login status > /dev/null 2>&1; then
    echo "PASS signed in: $(codex login status 2>&1 | head -n 1)"
  else
    echo "FAIL not signed in: run codex login"
    return 1
  fi
  d=$(mktemp -d)
  printf 'Remember the word "amber". Reply with one word: OK\n' > "$d/p1.md"
  printf 'Which word did I ask you to remember? Reply with that word only.\n' > "$d/p2.md"
  if s=$(call "$d" "$d/o1.md" "$d/p1.md"); then
    echo "PASS start: $s"
    if s=$(call "$d" "$d/o2.md" "$d/p2.md") && grep -qi amber "$d/o2.md"; then
      echo "PASS resume: Codex remembered the first turn"
    else
      echo "FAIL resume: $s; answer: $(cat "$d/o2.md" 2> /dev/null)"
    fi
  else
    echo "FAIL start: $s"
  fi
  state="$d/codex"
  forget_session
  rm -rf "$d"
}

if [ "${1:-}" = --ready ]; then
  ready
  exit $?
fi

if ! command -v codex > /dev/null 2>&1; then
  echo "CODEX_UNAVAILABLE: Codex CLI is not installed"
  exit 1
fi

case "${1:-}" in
  --check) check ;;
  --cleanup) state="$2/codex"; forget_session; echo "OK cleanup" ;;
  *)
    if [ $# -lt 3 ]; then
      echo "usage: codex.sh <dir> <out> <prompt> [file...] | --ready | --check | --cleanup <dir>" >&2
      exit 2
    fi
    call "$@"
    ;;
esac
