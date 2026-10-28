<?php

$buffer = new ArrayBuffer(80, max_byte_length: 160);
echo "byteLength = ", $buffer->byteLength, "\n";
echo "detached = ", $buffer->detached, "\n";
echo "maxByteLength = ", $buffer->maxByteLength, "\n";
echo "resizable = ", $buffer->resizable, "\n";
echo "strlen = ", strlen((string) $buffer), "\n";
echo "strlen = ", strlen($buffer->slice(6, 15)), "\n";
echo "strlen = ", strlen($buffer->slice(-5)), "\n";
$other = $buffer->transfer();
echo "detached = ", $buffer->detached, "\n";
echo "byteLength = ", $other->byteLength, "\n";
