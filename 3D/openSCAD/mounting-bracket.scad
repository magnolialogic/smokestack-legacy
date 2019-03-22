$fn=48;

height=10;
innerDiameter=4.5;
wallThickness=2;

frontAlign=0;
rightAlign=90.5;
leftAlign=0;
middleAlign=60;
backAlign=120;

difference() {
	union() {
		cylinder(height, d=innerDiameter+wallThickness*2);
		translate([frontAlign, rightAlign, 0]) cylinder(height, d=innerDiameter+wallThickness*2);
		translate([middleAlign, leftAlign, 0]) cylinder(height, d=innerDiameter+wallThickness*2);
		translate([middleAlign, rightAlign, 0]) cylinder(height, d=innerDiameter+wallThickness*2);
		translate([backAlign, leftAlign, 0]) cylinder(height, d=innerDiameter+wallThickness*2);
		translate([backAlign, rightAlign, 0]) cylinder(height, d=innerDiameter+wallThickness*2);
		translate([-(wallThickness/2), leftAlign+wallThickness, 0]) cube([wallThickness, rightAlign-wallThickness*2, height]);
		translate([frontAlign+wallThickness, -(wallThickness/2), 0]) cube([backAlign-wallThickness*2, wallThickness, height]);
		translate([frontAlign+wallThickness, rightAlign-(wallThickness/2), 0]) cube([115, wallThickness, height]);
		
	}
	translate([frontAlign, leftAlign, -0.1]) cylinder(height+1, d=innerDiameter);
	translate([frontAlign, rightAlign, -0.1]) cylinder(height+1, d=innerDiameter);
	translate([middleAlign, leftAlign, -0.1]) cylinder(height+1, d=innerDiameter);
	translate([middleAlign, rightAlign, -0.1]) cylinder(height+1, d=innerDiameter);
	translate([backAlign, leftAlign, -0.1]) cylinder(height+1, d=innerDiameter);
	translate([backAlign, rightAlign, -0.1]) cylinder(height+1, d=innerDiameter);
}