<?php

use zig\roaring\Bitmap;

$bm1 = new Bitmap([1, 2, 3, 4000]);
// echo "1 => ", $bm1[1], "\n";
// echo "4000 => ", $bm1[4000], "\n";
// echo "4001 => ", $bm1[4001], "\n";

// print_r($bm1);
// foreach ($bm1 as $key => $value) {
//     echo "$key => $value\n";
// }

$bm2 = new Bitmap([1, 2, 3, 4000]);
echo "equal = ", $bm2 == $bm1, "\n";
$bm2 = new Bitmap([1, 4, 3, 4001]);
echo "equal = ", $bm2 == $bm1, "\n";

$bm3 = $bm1 & $bm2;
print_r($bm3);
$bm3 = $bm1 | $bm2;
print_r($bm3);
$bm3 = $bm1 ^ $bm2;
print_r($bm3);

