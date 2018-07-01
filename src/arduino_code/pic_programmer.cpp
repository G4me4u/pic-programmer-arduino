#include "./pic_programmer.h"

PicProgrammer::PicProgrammer(unsigned int flags)
	: programming(false),
	  lowVoltageMode((flags & LOW_VOLTAGE_PROGRAMMING_MASK) != 0),
	  address(-1L),
	  extendedAddress(0)
{ }

PicProgrammer::~PicProgrammer()
{ }
