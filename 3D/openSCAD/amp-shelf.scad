$fn=48;

minWidth=5;
tcAmpY=15;
rtdAmpY=20;
totalX=49+minWidth;
totalY=68.5+minWidth;
totalZ=2.5;
m25=3;
m2=2.5;

postLeftAlign=minWidth/2;
postRightAlign=totalY-minWidth/2;
postFrontAlign=minWidth/2;
postBackAlign=totalX-minWidth/2;
mountFrontAlign=postFrontAlign+10;
tcHole1Align=minWidth*2.5;
tcHole2Align=tcHole1Align+tcAmpY;
rtdHole1Align=tcHole2Align+minWidth*2.5;
rtdHole2Align=rtdHole1Align+rtdAmpY;

module createCrossBraces (frontAlign, leftAlign, openingWidth, braceAngle) {
	translate([frontAlign, leftAlign, 0]) rotate(a=[0,0,-braceAngle]) cube([minWidth/2, 200, totalZ*2], center=true);
	translate([frontAlign, leftAlign+openingWidth, 0]) rotate(a=[0,0,braceAngle]) cube([minWidth/2, 200, totalZ*2], center=true);
}

union() {
	difference() {
		// Master frame
		cube([totalX, totalY, totalZ]);
		
		// Front cutout
		translate([-0.1, minWidth, -0.1]) cube([10.1, totalY-minWidth*2, 3]);
		
		// Rear cutout
		translate([29, minWidth, -0.1]) cube([40, (totalY-(2*minWidth)), 5]);
		
		// Holes for posts
		translate([postFrontAlign, postLeftAlign, -0.1]) cylinder(h=10, d=m25, center=true);
		translate([postFrontAlign, postRightAlign, -0.1]) cylinder(h=10, d=m25, center=true);
		translate([postBackAlign, postLeftAlign, -0.1]) cylinder(h=10, d=m25, center=true);
		translate([postBackAlign, postRightAlign, -0.1]) cylinder(h=10, d=m25, center=true);
		
		// Holes for TC amp board
		translate([mountFrontAlign, tcHole1Align, -0.1]) cylinder(h=10, d=m25, center=true);
		translate([mountFrontAlign, tcHole2Align, -0.1]) cylinder(h=10, d=m25, center=true);
		
		// Holes for RTD amp board
		translate([mountFrontAlign, rtdHole1Align, -0.1]) cylinder(h=10, d=m25, center=true);
		translate([mountFrontAlign, rtdHole2Align, -0.1]) cylinder(h=10, d=m25, center=true);
		}
		
		// TC shelf
		difference() {
			translate([24, tcHole1Align-2.75-minWidth/2, totalZ]) cube([5, tcAmpY+5.5+minWidth, minWidth*1.2]);	
			translate([23, tcHole1Align-2.75, totalZ*2+1]) cube([20, tcAmpY+5.5, minWidth*2]);
		}
		
		// RTD shelf
		difference() {
			translate([24, rtdHole1Align-2.75-minWidth/2, totalZ]) cube([5, rtdAmpY+5.5+minWidth, minWidth*1.2]);	
			translate([23, rtdHole1Align-2.75, totalZ*2+1]) cube([20, rtdAmpY+5.5, minWidth*2]);
		}
}