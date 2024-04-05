import binary show LITTLE-ENDIAN BIG-ENDIAN

pack-16 value -> ByteArray:
  buffer := ByteArray 2
  BIG-ENDIAN.put-uint16 buffer 0 value
  return buffer

unpack-16 buffer/ByteArray -> int:
  return BIG-ENDIAN.uint16 buffer 0

pack-32 value -> ByteArray:
  buffer := ByteArray 4
  BIG-ENDIAN.put-uint32 buffer 0 value
  return buffer

unpack-32 buffer/ByteArray -> int:
  return BIG-ENDIAN.uint32 buffer 0
