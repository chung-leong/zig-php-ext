<?php

// assemble([
//     [ 'real_name' => "Tony Stark", 'superhero_name' => "Ironman", 'power' => Power::tech ],
//     [ 'real_name' => "Natalia Romanov", 'superhero_name' => "Black Widow" ],
//     [ 'real_name' => "Peter Parker", 'superhero_name' => "Blue Beetle", 'power' => Power::mutant ],
// ]);

class Superhero {
    function __construct($real_name, $superhero_name, $power) {
        $this->real_name = $real_name;
        $this->superhero_name = $superhero_name;
        $this->power = $power;
    }
}

assemble([
    new Superhero("Tony Stark", "Ironman", Power::tech),
    new Superhero("Natalia Romanov", "Black Widow", Power::training),
    new Superhero("Peter Parker", "Hawkeye", Power::mutant),
]);

?>