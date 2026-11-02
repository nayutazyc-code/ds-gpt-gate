ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TASKS="$ROOT/tasks"
die(){ echo "错误: $*" >&2; exit 1; }
tdir(){ local d="$TASKS/$1"; [[ -f "$d/state.json" ]] || die "任务不存在: $1"; echo "$d"; }
jget(){ jq -r "$2" "$1/state.json"; }
jset(){ local t; t=$(mktemp); jq "${@:2}" "$1/state.json" >"$t" && mv "$t" "$1/state.json"; }
now(){ date '+%Y-%m-%dT%H:%M:%S%z'; }
# 仅在需要时把 DEEPSEEK_API_KEY 从 ~/.dsh/.credentials.yaml 载入当前进程环境（不回显）
ensure_deepseek_key(){
  [[ -n ${DEEPSEEK_API_KEY:-} ]] && return 0
  local k; k=$(node -e '
const fs=require("fs"),p=require("os").homedir()+"/.dsh/.credentials.yaml";
let y; try{y=require(require.resolve("yaml",{paths:["/home/box/.local/lib/node_modules/@deepseek-ai/dsh/node_modules"]}))}catch(e){process.exit(2)}
const c=y.parse(fs.readFileSync(p,"utf8"))||{}; const r=c.refs&&c.refs.DEEPSEEK_API_KEY;
const id=typeof r==="string"?r:(r&&(r.record||r.id||r.ref));
if(typeof r==="string"&&/^sk-/.test(r)){process.stdout.write(r);process.exit(0)}
const rec=c.records&&(Array.isArray(c.records)?c.records.find(x=>x.id===id):c.records[id]);
const s=rec&&(typeof rec==="string"?rec:((rec.payload&&rec.payload.secret)||rec.secret||rec.value)); if(!s)process.exit(3); process.stdout.write(s);' 2>/dev/null) || return 1
  export DEEPSEEK_API_KEY="$k"
}
