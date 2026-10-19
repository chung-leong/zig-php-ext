<?php

$string = "Existing text";
setStrings($string);
echo $string, "\n";
setStrings($string, $another);
echo $string, "\n";
echo $another, "\n";
