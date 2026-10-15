<?php

$object = new WithCastObject(3);
if ($object < 4) echo "less than 4\n";
if ($object > 2.9) echo "greater than 2.9\n";
if ($object == 3) echo "equals 3\n";

try {
    echo $object < "hello"; 
} catch (Exception $e) {
    echo $e->getMessage(), "\n";
}
