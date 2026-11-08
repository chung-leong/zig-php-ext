<?php

use zig\roaring\Bitmap;

$bm1 = new Bitmap([1, 2, 3, 4000]);
$bm1[47] = true;
$bm1->freeze();
$bytes = (string) $bm1;
echo "length = ", strlen($bytes), "\n";
$bm2 = new Bitmap($bytes);
print_r($bm2);
