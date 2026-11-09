<?php

$states = [
    "Alabama",
    "Alaska",
    "Arizona",
    "Arkansas",
    "California",
    "Colorado",
    "Connecticut",
    "Delaware",
    "Florida",
    "Georgia",
    "Hawaii",
    "Idaho",
    "Illinois",
    "Indiana",
    "Iowa",
    "Kansas",
    "Kentucky",
    "Louisiana",
    "Maine",
    "Maryland",
    "Massachusetts",
    "Michigan",
    "Minnesota",
    "Mississippi",
    "Missouri",
    "Montana",
    "Nebraska",
    "Nevada",
    "New Hampshire",
    "New Jersey",
    "New Mexico",
    "New York",
    "North Carolina",
    "North Dakota",
    "Ohio",
    "Oklahoma",
    "Oregon",
    "Pennsylvania",
    "Rhode Island",
    "South Carolina",
    "South Dakota",
    "Tennessee",
    "Texas",
    "Utah",
    "Vermont",
    "Virginia",
    "Washington",
    "West Virginia",
    "Wisconsin",
    "Wyoming"
];

$text = file_get_contents(__DIR__ . "/sample-long.txt");
$replacements = [];
foreach ($states as $state) {
    $replacements[$state] = "**$state**";
}

// extension function
$start = hrtime(true);
for ($i = 0; $i < 1000; $i++) {
    $s = replace_states($text, $replacements);
}
$end = hrtime(true);
echo "extension: ", ($end - $start) / 100_000_000, "\n";

// builtin function
$start = hrtime(true);
for ($i = 0; $i < 1000; $i++) {
    $s = strtr($text, $replacements);
}
$end = hrtime(true);
echo "strtr: ", ($end - $start) / 100_000_000, "\n";

