<?php

// From a length
$int32 = new Float64Array(2);
$int32[0] = 42.5;
echo $int32[0], "\n"; // 42.5
echo $int32->length, "\n"; // 2
echo Float64Array::BYTES_PER_ELEMENT, "\n"; // 8

// From an array
$x = new Float64Array([21.5, 31.5]);
echo $x[1], "\n"; // 31.5

// From another TypedArray
$y = new Float64Array($x);
echo $y[0], "\n"; // 21.5

// From an ArrayBuffer
$buffer = new ArrayBuffer(64);
$z = new Float64Array($buffer, 8, 4);
echo $z->byteOffset, "\n"; // 8

