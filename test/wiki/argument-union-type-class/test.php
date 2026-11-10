<?php

poke(new Dog);
poke(new Cat);
poke(new Fox);
try {
    poke(new stdclass);
} catch (Exception $e) {
    echo $e->getMessage(), "\n";
}
