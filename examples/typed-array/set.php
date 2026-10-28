<?php

$buffer = new ArrayBuffer(8);
$uint8 = new Uint8Array($buffer);

$uint8->set([1, 2, 3], 3);

print_r($uint8); // Uint8Array [ 0, 0, 0, 1, 2, 3, 0, 0 ]
