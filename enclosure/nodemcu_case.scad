// NodeMCU ESP8266 ESP-12F (USB-C) Enclosure
// Snap-fit box with USB-C port cutout and wire exit slot

/* [Board Dimensions] */
// NodeMCU PCB (without headers)
pcb_length = 49;    // mm
pcb_width  = 26;    // mm
pcb_thick  = 1.6;   // mm
header_height = 8.5; // pin header height below PCB
wire_bend_clearance = 5; // extra depth below headers for wires to bend

/* [USB-C Port] */
usbc_width  = 9;
usbc_height = 3.5;
usbc_z_offset = 0;  // relative to PCB top surface

/* [Wire Exit] */
wire_slot_width = 12; // wide enough for 3 wires
wire_slot_height = 5;

/* [Case Parameters] */
wall       = 2;       // wall thickness
clearance  = 0.5;     // gap around PCB
post_d     = 4;       // support post diameter
post_hole  = 2;       // screw hole diameter (M2)
lid_lip    = 1.5;     // lip height for snap fit
snap_nub   = 0.4;     // snap nub size
corner_r   = 2;       // corner rounding radius

/* [Computed] */
// Interior dimensions
inner_l = pcb_length + clearance * 2;
inner_w = pcb_width + clearance * 2;
inner_h = wire_bend_clearance + header_height + pcb_thick + 3; // bend clearance + headers + PCB + headroom

// Outer dimensions
outer_l = inner_l + wall * 2;
outer_w = inner_w + wall * 2;
outer_h = inner_h + wall; // bottom wall only, lid is separate

// PCB rests on posts at header_height
pcb_z = wall + wire_bend_clearance + header_height;

/* [Rendering] */
part = "both"; // [base, lid, both]
explode = 10;  // explode distance for "both" view

module rounded_box(l, w, h, r) {
    hull() {
        for (x = [r, l - r])
            for (y = [r, w - r])
                translate([x, y, 0])
                    cylinder(r = r, h = h, $fn = 24);
    }
}

module base() {
    difference() {
        // Outer shell
        rounded_box(outer_l, outer_w, outer_h, corner_r);

        // Inner cavity
        translate([wall, wall, wall])
            rounded_box(inner_l, inner_w, inner_h + 1, max(corner_r - wall, 0.5));

        // USB-C port cutout (on +X end)
        translate([
            outer_l - wall - 0.5,
            outer_w / 2 - usbc_width / 2,
            pcb_z + usbc_z_offset
        ])
            cube([wall + 1, usbc_width, usbc_height]);

        // Wire exit slot (on -X end)
        translate([
            -0.5,
            outer_w / 2 - wire_slot_width / 2,
            pcb_z - 2
        ])
            cube([wall + 1, wire_slot_width, wire_slot_height]);
    }

    // PCB support posts (4 corners)
    post_inset = 2; // mm from PCB edge
    for (x = [wall + clearance + post_inset,
              wall + clearance + pcb_length - post_inset])
        for (y = [wall + clearance + post_inset,
                  wall + clearance + pcb_width - post_inset])
            translate([x, y, wall])
                difference() {
                    cylinder(d = post_d, h = wire_bend_clearance + header_height, $fn = 20);
                    cylinder(d = post_hole, h = wire_bend_clearance + header_height + 0.1, $fn = 16);
                }

    // Lid snap nubs on inner walls (long sides)
    for (y = [wall - snap_nub, outer_w - wall])
        for (x = [outer_l * 0.25, outer_l * 0.75])
            translate([x, y, outer_h - lid_lip / 2])
                cube([4, snap_nub, lid_lip / 2]);
}

module lid() {
    lip_clearance = 0.3;

    // Flat top
    difference() {
        rounded_box(outer_l, outer_w, wall, corner_r);

        // Ventilation slots
        for (x = [outer_l * 0.3, outer_l * 0.5, outer_l * 0.7])
            translate([x - 4, outer_w * 0.3, -0.5])
                cube([8, outer_w * 0.4, wall + 1]);
    }

    // Inner lip that fits inside base
    translate([wall + lip_clearance, wall + lip_clearance, wall])
        difference() {
            rounded_box(
                inner_l - lip_clearance * 2,
                inner_w - lip_clearance * 2,
                lid_lip,
                max(corner_r - wall, 0.5)
            );
            translate([wall / 2, wall / 2, -0.1])
                rounded_box(
                    inner_l - lip_clearance * 2 - wall,
                    inner_w - lip_clearance * 2 - wall,
                    lid_lip + 0.2,
                    max(corner_r - wall * 1.5, 0.3)
                );
        }
}

if (part == "base" || part == "both") {
    base();
}

if (part == "lid" || part == "both") {
    translate([0, 0, outer_h + explode])
        lid();
}
