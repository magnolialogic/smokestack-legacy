$fn=48;

totalX=15+2.5+10+(107/2)+(162/2)+5;
totalY=95;
totalZ=2.5;
screwHoleSpacing=101.6+22.22;

difference() {
	union() {
		cube([totalX, totalY, totalZ]);
		translate([totalX-5, 0, totalZ]) cube([5, totalY, 25]);
	}
	translate([(15+2.5/2), totalY/2, -0.1]) cylinder(10, d=3.5);
	translate([(15+2.5/2)+screwHoleSpacing, totalY/2, -0.1]) cylinder(10, d=3.5);
	translate([totalX-6, 20, totalZ+10]) cube([10, totalY-20*2, 20]);
}