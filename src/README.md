## Toit usage
flash: `jag flash -p COM19 --chip esp32s3`
install container: `jag container install app -D jag.disabled -D jag.timeout=5m src/main.toit`

## Full Firmware build
compile main app `toit.compile -w komodo.snapshot src/toit/src/komodo.toit`
install container to envelope: `firmware -e firmware-esp32s3.envelope  container install komodo komodo.snapshot`
flash: `firmware -e firmware-esp32s3.envelope flash -p COM19 --baud 921600 --chip esp32s3`