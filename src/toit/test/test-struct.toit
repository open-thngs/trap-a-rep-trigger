import .testoiteron
import app.struct as struct

class TestSensorCfg implements TestCase:

  run:
    test-struct-pack-16
    test-struct-pack-32

  test-struct-pack-16:
    buffer := struct.pack-16 0x1234
    assertEquals #[0x12, 0x34] buffer
    assertEquals 0x1234 (struct.unpack-16 buffer)

  test-struct-pack-32:
    buffer := struct.pack-32 0x1234
    assertEquals #[0x00, 0x00, 0x12, 0x34] buffer
    assertEquals 0x1234 (struct.unpack-32 buffer)

main:
  test := TestSensorCfg
  test.run