// NodeMCU ESP8266 ESP-12F (USB-C) Enclosure
// Single box; board inserts vertically from top (USB-C up); cap closes top.

/* [Internal Cavity] */
inner_x = 26;   // width (matches PCB width)
inner_y = 24;   // depth
inner_z = 52;   // main height (PCB height); USB-C adds 2mm into cap

/* [Board] */
pcb_thick    = 1.5;
component_h  = 3;    // tallest component above PCB face (reference)

/* [USB-C Port] */
usbc_w = 9;
usbc_h = 3.5;

/* [Case] */
wall      = 2;
cap_lip   = 4;     // cap lip insertion depth into box
cap_clear = 0.3;   // cap-to-box lateral clearance

/* [Slide Rails] */
rail_h      = 6;
rail_w      = 2.5;
rail_gap    = pcb_thick + 0.3;  // groove width (PCB + clearance)
rail_offset = 3;                 // gap between back wall and first rail

/* [Computed PCB position] */
pcb_y = wall + rail_offset + rail_w + rail_gap / 2;  // PCB centerline Y

/* [Computed] */
outer_x = inner_x + wall * 2;
outer_y = inner_y + wall * 2;
outer_z = inner_z + wall;    // bottom wall only; top is open for cap

/* [Rendering] */
part    = "both";   // [box, cap, both]
explode = 12;

module box() {
    difference() {
        cube([outer_x, outer_y, outer_z]);

        // Main cavity (open top)
        translate([wall, wall, wall])
            cube([inner_x, inner_y, inner_z + 1]);
    }

    // Two parallel rails at bottom form the PCB slide groove
    // Offset `rail_offset` from the back wall (Y=0 side)
    y1 = wall + rail_offset;
    y2 = y1 + rail_w + rail_gap;
    for (y = [y1, y2])
        translate([wall, y, wall])
            cube([inner_x, rail_w, rail_h]);
}

module cap() {
    difference() {
        union() {
            // Top plate
            cube([outer_x, outer_y, wall]);

            // Lip that slides into the box opening
            translate([wall + cap_clear, wall + cap_clear, -cap_lip])
                cube([
                    inner_x - cap_clear * 2,
                    inner_y - cap_clear * 2,
                    cap_lip
                ]);
        }

        // USB-C cutout: through top plate AND lip (full cap depth)
        translate([
            outer_x / 2 - usbc_w / 2,
            pcb_y - usbc_h / 2,
            -cap_lip - 0.1
        ])
            cube([usbc_w, usbc_h, cap_lip + wall + 0.2]);
    }
}

if (part == "box" || part == "both")
    box();

if (part == "cap" || part == "both")
    translate([0, 0, outer_z + explode])
        cap();
