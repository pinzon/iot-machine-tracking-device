// SW-420 Vibration Sensor Enclosure
// Small box with wire exit, thin bottom for vibration transfer

/* [Board Dimensions] */
// SW-420 module PCB
pcb_length = 32;    // mm
pcb_width  = 14;    // mm
pcb_thick  = 1.6;   // mm
component_height = 5; // tallest component on top (potentiometer/LED)
pin_height = 2.5;   // pin length below PCB
pin_length = 10;    // pins extend from PCB edge + wire connectors

/* [Wire Exit] */
wire_slot_width = 10; // 3 wires
wire_slot_height = 4;

/* [Case Parameters] */
wall       = 2;       // wall thickness
bottom     = 1;       // thinner bottom to transmit vibration
clearance  = 0.5;     // gap around PCB
post_d     = 3;       // support post diameter
lid_lip    = 1.5;     // lip height for friction fit
snap_nub   = 0.4;     // snap nub size
corner_r   = 1.5;     // corner rounding radius

/* [Computed] */
inner_l = pcb_length + pin_length + clearance * 2;
inner_w = pcb_width + clearance * 2;
inner_h = pin_height + pcb_thick + component_height + 2; // 2mm headroom

outer_l = inner_l + wall * 2;
outer_w = inner_w + wall * 2;
outer_h = inner_h + bottom;

pcb_z = bottom + pin_height;

/* [Rendering] */
part = "both"; // [base, lid, both]
explode = 8;

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
        translate([wall, wall, bottom])
            rounded_box(inner_l, inner_w, inner_h + 1, max(corner_r - wall, 0.5));

        // Wire exit slot (on -X end)
        translate([
            -0.5,
            outer_w / 2 - wire_slot_width / 2,
            pcb_z - 1
        ])
            cube([wall + 1, wire_slot_width, wire_slot_height]);
    }

    // PCB support posts (4 corners)
    post_inset = 1.5;
    for (x = [wall + clearance + post_inset,
              wall + clearance + pcb_length - post_inset])
        for (y = [wall + clearance + post_inset,
                  wall + clearance + pcb_width - post_inset])
            translate([x, y, bottom])
                cylinder(d = post_d, h = pin_height, $fn = 16);

    // Lid snap nubs on inner walls (long sides)
    for (y = [wall - snap_nub, outer_w - wall])
        for (x = [outer_l * 0.3, outer_l * 0.7])
            translate([x, y, outer_h - lid_lip / 2])
                cube([3, snap_nub, lid_lip / 2]);
}

module lid() {
    lip_clearance = 0.3;

    // Flat top
    rounded_box(outer_l, outer_w, wall, corner_r);

    // Inner lip
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
