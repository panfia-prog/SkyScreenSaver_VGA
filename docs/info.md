<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

This project primarily uses the input pins, the following is what each input pin does:
ui_in[0] - Day-Cycle (if on)/Night-Cycle (if off)
ui_in[1] - Sunrise/Waning Crescent
ui_in[2] - Early Morning/Third Quarter
ui_in[3] - Morning/Waning Gibbous
ui_in[4] - Midday/Full Moon
ui_in[5] - Early Afternoon/Waxing Gibbous
ui_in[6] - Late Afternoon/First Quarter
ui_in[7] - Sunset/Waxing Crescent

The output prioritizes the latter switches (i.e. if both ui_in[2] and ui_in[5] are on, it will output ui_in[5])

## How to test

To be Added

## External hardware

N/A
