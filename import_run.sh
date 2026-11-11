#!/usr/bin/env bash
set -e

SRC_DIR="$1"
if [ -z "$SRC_DIR" ] || [ ! -d "$SRC_DIR" ]; then
  echo "Usage: ./import_run.sh /path/to/friend_workspace"
  exit 1
fi

echo "[1/4] Copying SystemVerilog (.sv) files into verilog/..."
find "$SRC_DIR" -maxdepth 2 -name "*.sv" -exec cp -f {} /workspace/verilog/ \;

echo "[2/4] Copying config.json, .def, and .loc files into run/config/..."
for f in config.json lvs_config.json A68_A.def vsrc_vdd.loc vsrc_vss.loc "perintah .loc"; do
  if [ -f "$SRC_DIR/$f" ]; then
    cp -f "$SRC_DIR/$f" /workspace/run/config/
  fi
done

echo "[3/4] Updating VERILOG_FILES paths in run/config/config.json..."
python3 -c '
import json, pathlib
p = pathlib.Path("/workspace/run/config/config.json")
if p.exists():
    cfg = json.loads(p.read_text())
    cfg["VERILOG_FILES"] = [
        "dir::../../verilog/" + f.split("/")[-1].replace("dir::", "")
        for f in cfg.get("VERILOG_FILES", [])
    ]
    p.write_text(json.dumps(cfg, indent=4) + "\n")
'

echo "[4/4] Copying latest LibreLane run into run/result/..."
LATEST_RUN=$(find "$SRC_DIR/runs" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort | tail -n 1)
if [ -n "$LATEST_RUN" ]; then
  cp -rf "$LATEST_RUN" /workspace/run/result/
  echo "Copied run: $(basename "$LATEST_RUN") -> run/result/"
fi

echo "Done! All files imported into the formatted structure."
