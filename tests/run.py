"""Run behavioral checks in an isolated Factorio instance, without touching player saves."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
from threading import Timer

parser = argparse.ArgumentParser()
parser.add_argument("factorio", type=Path)
parser.add_argument("--power", choices=["free", "normal", "extreme"], default="normal")
parser.add_argument("--speed", choices=["ultra-slow", "slow", "normal", "fast", "ultra-fast"], default="normal")
parser.add_argument("--stacks", type=int, default=1, choices=range(1, 11))
parser.add_argument("--rocket", type=int, default=0, choices=[0, 1, 2, 3, 5, 10])
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
qa = Path(tempfile.mkdtemp(prefix="iln-tests-"))
mods = qa / "mods"
mods.mkdir()
(mods / root.name).symlink_to(root, target_is_directory=True)
harness = mods / "iln-integration-tests"
harness.mkdir()
(harness / "info.json").write_text(json.dumps({"name": "iln-integration-tests", "version": "1.0.0", "title": "ILN integration tests", "author": "ILN", "factorio_version": json.loads((root / "info.json").read_text())["factorio_version"], "dependencies": ["interplanetary-logistics-network"]}))
(harness / "settings-updates.lua").write_text(
    'data.raw["string-setting"]["interplanetary-power-cost"].default_value = ' + json.dumps(args.power) + '\n'
    + 'data.raw["string-setting"]["interplanetary-transfer-speed"].default_value = ' + json.dumps(args.speed) + '\n'
    + 'data.raw["int-setting"]["interplanetary-stacks-per-transfer"].default_value = ' + str(args.stacks) + '\n'
    + 'data.raw["int-setting"]["interplanetary-rocket-capacity"].default_value = ' + str(args.rocket) + '\n')

scenario = qa / "scenarios" / "integration"
scenario.mkdir(parents=True)
(scenario / "control.lua").write_bytes((root / "tests/control.lua").read_bytes())
(mods / "mod-list.json").write_text(json.dumps({"mods": [{"name": n, "enabled": True} for n in ["base", "quality", "elevated-rails", "space-age", root.name, "iln-integration-tests"]]}))
config = qa / "config.ini"
config.write_text("[path]\nread-data=__PATH__system-read-data__\nwrite-data=" + str(qa) + "\n[other]\ncheck-updates=false\nautosave-interval=0\n")
server = qa / "server.json"
example = next(p / "data/server-settings.example.json" for p in args.factorio.parents if (p / "data/server-settings.example.json").exists())
server_settings = json.loads(example.read_text())
server_settings.update({"name": "ILN isolated tests", "visibility": {"public": False, "lan": False}, "require_user_verification": False, "auto_pause": False, "autosave_interval": 0})
server.write_text(json.dumps(server_settings))
command = [str(args.factorio), "--config", str(config), "--mod-directory", str(mods), "--start-server-load-scenario", "integration", "--server-settings", str(server), "--bind", "127.0.0.1", "--port", "0", "--until-tick", "3601", "--disable-audio"]
process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.PIPE,
    text=True, env={**os.environ, "SteamAppId": "427520", "SteamGameId": "427520"})
timeout = Timer(120, process.kill)
timeout.start()
lines = []
for line in process.stdout:
    lines.append(line)
    if "ILN INTEGRATION PASS" in line:
        process.terminate()
        break
remaining, _ = process.communicate(timeout=10)
timeout.cancel()
log = "".join(lines) + remaining
(qa / "test.log").write_text(log)
print("Test artifacts:", qa)
print("\n".join(line for line in log.splitlines() if any(s in line for s in ["ILN", "Error", "error", "stack traceback", "control.lua:"]) and "Got EOF on stdin; closing" not in line))
if "ILN INTEGRATION PASS" not in log:
    print(log[-1500:])
    raise SystemExit(1)
