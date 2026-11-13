<?php

// Fruit::cherry->show();
try {
    Fruit::showAll();
} catch (Exception $e) {
    echo $e;
}