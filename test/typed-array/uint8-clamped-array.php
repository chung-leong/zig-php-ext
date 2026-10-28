<?php

// From a length
$uint8c = new Uint8ClampedArray(2);
$uint8c[0] = 42;
$uint8c[1] = 1337;

echo $uint8c[0], "\n"; // 42
echo $uint8c[1], "\n"; // 255 (clamped)
echo $uint8c->length, "\n"; // 2
echo Uint8ClampedArray::BYTES_PER_ELEMENT, "\n"; // 1

// From an array
$x = new Uint8ClampedArray([21, 31]);
echo $x[1], "\n"; // 31

// From another TypedArray
$y = new Uint8ClampedArray($x);
echo $y[0], "\n"; // 21

// From an ArrayBuffer
$buffer = new ArrayBuffer(8);
$z = new Uint8ClampedArray($buffer, 1, 4);
echo $z->byteOffset, "\n"; // 1
