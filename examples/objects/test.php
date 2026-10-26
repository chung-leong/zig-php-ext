<?php

class Superhero {
    function __construct($real_name, $superhero_name, $power) {
        $this->real_name = $real_name;
        $this->superhero_name = $superhero_name;
        $this->power = $power;
    }
}

show([ 'real_name' => "Tony Stark", 'superhero_name' => "Ironman", 'power' => Power::tech ]);

assemble([
    [ 'real_name' => "Tony Stark", 'superhero_name' => "Ironman", 'power' => 'tech' ],
    [ 'real_name' => "Natalia Romanov", 'superhero_name' => "Black Widow" ],
    [ 'real_name' => "Peter Parker", 'superhero_name' => "Blue Beetle", 'power' => 'mutant' ],
]);

print_r(get());
print_r(get_two());
print_r(get_multiple(5));

?>