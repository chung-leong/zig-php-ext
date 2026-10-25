<?php

use marvel\Avenger;
use marvel\Avenger\Power;

$avenger = new Avenger("Ironman", "Tony Stark", "tech");
$avenger->show();
$avenger->power = 'mutant';
$avenger->show();
print_r($avenger);

$avenger = new Avenger(real_name: "Peter Parker", superhero_name: "Antman", power: "tech");
print_r($avenger);

foreach ($avenger as $key => $value) {
    echo "$key = $value\n";
}

echo Avenger::Power, "\n";
echo Avenger::Power::mutant, "\n";
echo Power::mutant, "\n";

?>