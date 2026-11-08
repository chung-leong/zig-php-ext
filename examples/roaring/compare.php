<?php

use zig\roaring\Bitmap;

$bm1 = new Bitmap([1, 2, 3, 4000]);
$bm2 = new Bitmap([1, 2, 3, 4000]);
echo "equal = ", $bm2 == $bm1, "\n";
$bm2 = new Bitmap([1, 4, 3, 4001]);
echo "equal = ", $bm2 == $bm1, "\n";
