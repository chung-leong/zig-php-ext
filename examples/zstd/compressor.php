<?php

$compressor = new zstd\Compressor(level: 9);
$data = file_get_contents(__DIR__ . "/data/macbeth.txt");
$complete = $compressor->compress($data, true);

$compressor = new zstd\Compressor(level: 9);
$chunks = str_split($data, 1024);
$output = [];
foreach ($chunks as $chunk) {
    $s = $compressor->compress($chunk, false);
    if ($s) $output[] = $s;
}
$output[] = $compressor->compress("", true);
$combined = implode("", $output);

echo "complete = ", strlen($complete), "\n";
echo "combined = ", strlen($combined), "\n";
echo "complete == combined => ", $complete == $combined, "\n";
