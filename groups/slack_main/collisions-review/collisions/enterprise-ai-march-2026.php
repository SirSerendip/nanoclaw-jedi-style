<?php
$edition = json_decode(file_get_contents(__DIR__ . '/editions/2026-03-27.json'), true);
include __DIR__ . '/template.php';
