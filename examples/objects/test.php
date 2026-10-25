<?php

// assemble([
//     [ 'real_name' => "Tony Stark", 'superhero_name' => "Ironman" ],
//     [ 'real_name' => "Natalia Romanov", 'superhero_name' => "Black Widow" ],
//     [ 'real_name' => "Peter Parker", 'superhero_name' => "Blue Beetle" ],
// ]);

class Superhero {
    function __construct($real_name, $superhero_name) {
        $this->real_name = $real_name;
        $this->superhero_name = $superhero_name;
    }
}

$tony = new stdclass;
$tony->real_name = "Tony Stark";
$tony->superhero_name = "Ironman";

assemble([
    $tony,
    // [ 'real_name' => "Tony Stark", 'superhero_name' => "Ironman" ],
    // new Superhero("Tony Stark", "Ironman"),
    // new Superhero("Natalia Romanov", "Black Widow"),
    // new Superhero("Peter Parker", "Hawkeye"),
]);

?>