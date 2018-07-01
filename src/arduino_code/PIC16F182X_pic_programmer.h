/*
 * Uses the same programming specification as the PIC12F1822
 * PicProgrammer.
 *
 * Refer to datasheet on Memory Programming:
 *
 * PIC12(L)F1822/PIC16(L)F182X Memory Programming Specification
 * URL: http://ww1.microchip.com/downloads/en/DeviceDoc/41390D.pdf
 */

#pragma once

#include "./PIC12F1822_pic_programmer.h"

class PIC16F182X_PicProgrammer : public PIC12F1822_PicProgrammer
{

public:
	PIC16F182X_PicProgrammer(unsigned int flags)
		: PIC12F1822_PicProgrammer(flags)
	{ }

};
