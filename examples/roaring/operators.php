<?php

use zig\roaring\Bitmap;

$bm1 = new Bitmap([1, 2, 3, 4000]);
$bm2 = new Bitmap([1, 4, 3, 4001]);

$bm3 = $bm1 & $bm2;
print_r($bm3);
$bm3 = $bm1 | $bm2;
print_r($bm3);
$bm3 = $bm1 ^ $bm2;
print_r($bm3);
