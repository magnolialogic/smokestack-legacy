


// Globals



$fn=48;
minWidth=5;
distanceFromFront=10;
mountingHoleDiameter=4.3;
standoffHoleDiameter=3.1;



// Sizes



relayBoardX=48.5-minWidth;
relayBoardY=68.5-minWidth;

piX=23-minWidth;
piY=58-minWidth;

powerX=27.2;
powerY=52.4;

totalX=relayBoardX+piX+powerX+minWidth*7.5;
totalY=relayBoardY+minWidth*2;
totalZ=2.5;

mountingWingX=130;
mountingWingY=105;

wireBlockX=18.75;
wireBlockY=30;
wireBlockZ=8;



// Alignments



rbCutoutLeftAlign=minWidth;
rbCutoutFrontAlign=distanceFromFront+wireBlockX+minWidth;
rbPostLeftAlign=minWidth/2;
rbPostRightAlign=totalY-minWidth/2;
rbPostFrontAlign=distanceFromFront+minWidth/2;
rbPostBackAlign=rbPostFrontAlign+relayBoardX+minWidth;
piCutoutLeftAlign=(totalY-piY)/2;
piPostLeftAlign=piCutoutLeftAlign-minWidth/2;
piPostRightAlign=piCutoutLeftAlign+minWidth/2+piY;
piPostFrontAlign=rbPostBackAlign+10;
piCutoutFrontAlign=piPostFrontAlign+minWidth/2;
piPostBackAlign=piPostFrontAlign+piX+minWidth;
psCutoutFrontAlign=piPostBackAlign+minWidth;
psCutoutRightAlign1=((totalY/2-26));
psCutoutRightAlign2=((totalY/2+10));
mountingPostLeftAlign=totalY/2-45.25;
mountingPostRightAlign=totalY/2+45.25;
mountingPostFrontAlign=mountingWingX/2-60;
mountingPostRearAlign=mountingWingX/2+60;
rbBraceAngle=21.5;
piBraceAngle=19;



// Custom functions



module createCrossBraces (frontAlign, leftAlign, openingWidth, braceAngle) {
	translate([frontAlign, leftAlign, 0]) rotate(a=[0,0,-braceAngle]) cube([minWidth/2, 200, totalZ*2], center=true);
	translate([frontAlign, leftAlign+openingWidth, 0]) rotate(a=[0,0,braceAngle]) cube([minWidth/2, 200, totalZ*2], center=true);
}



// DRAW



union() {
	difference() {
		
		// Master frame
		translate([0,-((mountingWingY-totalY)/2), 0]) cube([mountingWingX, mountingWingY, totalZ]);
		
		// Cutout for relay board
		difference() {
			translate([rbCutoutFrontAlign, rbCutoutLeftAlign, -0.1]) cube([relayBoardX-rbCutoutFrontAlign+distanceFromFront+minWidth, relayBoardY, 10]);
			createCrossBraces(rbCutoutFrontAlign, rbCutoutLeftAlign, relayBoardY, rbBraceAngle);
		}
		
		// Cutout for wire splice box
		translate([distanceFromFront-0.1,(totalY/2)-15,-0.1]) cube([wireBlockX, wireBlockY, 5]);
		
		// Cutout for RPi
		difference() {
			translate([piCutoutFrontAlign, piCutoutLeftAlign, -0.1]) cube([piX, piY, 10]);
			createCrossBraces(piCutoutFrontAlign, piCutoutLeftAlign, piY, piBraceAngle);
		}
		
		// Cutouts for power supply
		translate([psCutoutFrontAlign+2, minWidth, -0.1]) cube([20, 20, 10]);
		translate([psCutoutFrontAlign, totalY-minWidth-20, -0.1]) cube([powerX+minWidth, 20, 10]);
		
		// Holes for relay board
		translate([rbPostFrontAlign, rbPostLeftAlign, -0.1]) cylinder(h=10, d=standoffHoleDiameter, center=true);
		translate([rbPostFrontAlign, rbPostRightAlign, -0.1]) cylinder(h=10, d=standoffHoleDiameter, center=true);
		translate([rbPostBackAlign, rbPostLeftAlign, -0.1]) cylinder(h=10, d=standoffHoleDiameter, center=true);
		translate([rbPostBackAlign, rbPostRightAlign, -0.1]) cylinder(h=10, d=standoffHoleDiameter, center=true);
		
		// Holes for RPi
		translate([piPostFrontAlign, piPostLeftAlign, -0.1]) cylinder(h=10, d=standoffHoleDiameter, center=true);
		translate([piPostFrontAlign, piPostRightAlign, -0.1]) cylinder(h=10, d=standoffHoleDiameter, center=true);
		translate([piPostBackAlign, piPostLeftAlign, -0.1]) cylinder(h=10, d=standoffHoleDiameter, center=true);
		translate([piPostBackAlign, piPostRightAlign, -0.1]) cylinder(h=10, d=standoffHoleDiameter, center=true);
		
		// Holes for enclosure mounting posts
		translate([mountingPostFrontAlign, mountingPostLeftAlign, -0.1]) cylinder(h=10, d=mountingHoleDiameter, center=true);
		translate([mountingPostFrontAlign, mountingPostRightAlign, -0.1]) cylinder(h=10, d=mountingHoleDiameter, center=true);
		translate([mountingWingX/2, mountingPostLeftAlign, -0.1]) cylinder(h=10, d=mountingHoleDiameter, center=true);
		translate([mountingWingX/2, mountingPostRightAlign, -0.1]) cylinder(h=10, d=mountingHoleDiameter, center=true);
		translate([mountingPostRearAlign, mountingPostLeftAlign, -0.1]) cylinder(h=10, d=mountingHoleDiameter, center=true);
		translate([mountingPostRearAlign, mountingPostRightAlign, -0.1]) cylinder(h=10, d=mountingHoleDiameter, center=true);
		
		// Cutout for front offset
		translate([0, 0, -0.1]) cube([distanceFromFront, totalY, 10]);
	}
	
	// Top extension
	translate([totalX, 0, 0]) cube([distanceFromFront-1, totalY, totalZ]);
	
	// Wire block holder
	difference() {
		translate([distanceFromFront,(totalY/2)-(wireBlockY/2+minWidth/2),0]) cube([wireBlockX+minWidth, wireBlockY+minWidth, totalZ*3]);
		translate([distanceFromFront-0.1,(totalY/2)-wireBlockY/2,-0.1]) cube([wireBlockX, wireBlockY, 10]);
		translate([distanceFromFront+wireBlockX+minWidth,0,totalZ]) rotate([0, 315, 0]) cube([10, 200, 10]);
	}
	
	// Power supply holder
	difference() {
		translate([psCutoutFrontAlign+powerX/2+minWidth/2, totalY/2, 0]) cube([powerX+minWidth, 32, totalZ*10], center=true);
		translate([psCutoutFrontAlign+minWidth/2, psCutoutRightAlign1, 7.5]) cube([powerX, 200, 6]);
		translate([0,0,-100]) cube([200,100,100]);
	}
}