<?php

use zig\roaring\Bitmap;

$bm = new Bitmap([1, 2, 3, 4000]);
$bm[4] = true;
$bm->freeze();
echo "3 => {$bm[3]}\n";
echo "78900 => {$bm[78900]}\n";
try {
    $bm[9] = true;
} catch (Exception $e) {
    echo $e->getMessage(), "\n";
}
print_r($bm);
