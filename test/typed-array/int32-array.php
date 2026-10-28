<?php

// From a length
$int32 = new Int32Array(2);
$int32[0] = 42;
echo $int32[0], "\n"; // 42
echo $int32->length, "\n"; // 2
echo Int32Array::BYTES_PER_ELEMENT, "\n"; // 4

// From an array
$x = new Int32Array([21, 31]);
echo $x[1], "\n"; // 31

// From another TypedArray
$y = new Int32Array($x);
echo $y[0], "\n"; // 21

// From an ArrayBuffer
$buffer = new ArrayBuffer(32);
$z = new Int32Array($buffer, 4, 4);
echo $z->byteOffset, "\n"; // 4

