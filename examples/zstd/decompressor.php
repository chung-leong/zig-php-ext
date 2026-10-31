<?php

$decompressor = new zstd\Decompressor();
$data = file_get_contents(__DIR__ . "/data/macbeth.txt.zst");
$complete = $decompressor->decompress($data);

$decompressor = new zstd\Decompressor();
$chunks = str_split($data, 1024);
$output = [];
foreach ($chunks as $chunk) {
    $s = $decompressor->decompress($chunk);
    if ($s) $output[] = $s;
}

$combined = implode("", $output);

echo "complete = ", strlen($complete), "\n";
echo "combined = ", strlen($combined), "\n";
echo "complete == combined => ", $complete == $combined, "\n";
