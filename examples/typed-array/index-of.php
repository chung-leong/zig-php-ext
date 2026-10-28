<?php

$uint8 = new Uint8Array([10, 20, 30, 40, 50]);

echo $uint8->indexOf(50), "\n";
// Expected output: 4

// From position 3
echo $uint8->indexOf(20, 3), "\n";
// Expected output: -1

echo $uint8->indexOf(51), "\n";
// Expected output: -1
