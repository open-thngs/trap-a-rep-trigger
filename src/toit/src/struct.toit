import io

pack-16 value -> ByteArray:
  buffer := ByteArray 2
  io.BIG-ENDIAN.put-uint16 buffer 0 value
  return buffer

unpack-16 buffer/ByteArray -> int:
  return io.BIG-ENDIAN.uint16 buffer 0

pack-32 value -> ByteArray:
  buffer := ByteArray 4
  io.BIG-ENDIAN.put-uint32 buffer 0 value
  return buffer

unpack-32 buffer/ByteArray -> int:
  return io.BIG-ENDIAN.uint32 buffer 0
