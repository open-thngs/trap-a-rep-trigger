echo "compile komodo snapshot"
toit.compile -w komodo.snapshot src/toit/src/komodo.toit
echo "install komodo snapshot into envelope"
firmware -e firmware-esp32s3.envelope container install komodo komodo.snapshot
echo "flash komodo firmware"
firmware -e firmware-esp32s3.envelope flash -p COM19 --baud 921600 --chip esp32s3
echo "copy komodo snapshot to cache"
snapshot_uuid=$(toit snapshot uuid komodo.snapshot)
cp komodo.snapshot /c/Users/Mirko/.cache/jaguar/snapshots/$snapshot_uuid.snapshot