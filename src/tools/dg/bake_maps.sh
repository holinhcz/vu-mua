set -e
cd /home/claude/dg
for m in doiche choque; do
  mkdir -p out/spr_$m && ln -sfn spr_$m out/spr
  node ex_map.js $m > log_map_$m.txt 2>&1
  python3 mk_bundles.py map:$m >> log_map_$m.txt 2>&1
  echo done $m >> log_map_$m.txt
done
