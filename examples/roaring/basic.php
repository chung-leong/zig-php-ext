<?php

use zig\roaring\Bitmap;

$bm1 = new Bitmap([1, 2, 3, 4000]);
echo "1 => ", $bm1[1], "\n";
echo "4000 => ", $bm1[4000], "\n";
echo "4001 => ", $bm1[4001], "\n";
