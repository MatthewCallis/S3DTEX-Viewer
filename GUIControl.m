#import "GUIControl.h"
#define MAX_WIDTH 800
#define MAX_HEIGHT 600

@implementation GUIControl

unsigned long RGB332toRGBA(unsigned short rgb332){
	unsigned short temp = CFSwapInt16LittleToHost(rgb332);	// swap bytes. may not be needed depending on your RGB565 data
	unsigned long int red, green, blue;						// Assuming >=32-bit long int. uint32_t, where art thou?
	red = temp & 0xe0;
	red |= red >> 3 | red >> 6;

	green = (temp << 3) & 0xe0;
	green |= green >> 3 | green >> 6;

	blue = temp & 0x3;
	blue |= blue << 2;
	blue |= blue << 4;

	return (blue << 16) | (green << 8) | red | 0xFF000000;
	//	return (red << 24) | (green << 16) | (blue << 8) | 0xFF;
}

unsigned long RGB444toRGBA(unsigned short rgb444){
	unsigned short temp = CFSwapInt16LittleToHost(rgb444);	// swap bytes. may not be needed depending on your RGB565 data
	unsigned long int red, green, blue;						// Assuming >=32-bit long int. uint32_t, where art thou?

	red = (temp & 0xf) << 4;
	green = ((temp >> 4) & 0xf) << 4;
	blue = ((temp >> 8) & 0xf) << 4;

	return (red << 16) | (green << 8) | blue | 0xFF000000;
//	return (red << 24) | (green << 16) | (blue << 8) | 0xFF;
}

unsigned long RGB555toRGBA(unsigned short rgb555){
	unsigned short temp = CFSwapInt16LittleToHost(rgb555);	// swap bytes. may not be needed depending on your RGB565 data
	unsigned long int red, green, blue;						// Assuming >=32-bit long int. uint32_t, where art thou?
	red = (temp >> 7) & 0xF8;
	green = (temp >> 2) & 0xF8;
	blue = (temp << 3) & 0xF8;
	return (blue << 16) | (green << 8) | red | 0xFF000000;
//	return (red << 24) | (green << 16) | (blue << 8) | 0xFF;
}

unsigned long RGB565toRGBA(unsigned short rgb565){
	unsigned short temp = CFSwapInt16LittleToHost(rgb565);	// swap bytes. may not be needed depending on your RGB565 data
	unsigned long int red, green, blue;						// Assuming >=32-bit long int. uint32_t, where art thou?

	red = (temp >> 11) & 0x1F;
	green = (temp >> 5) & 0x3F;
	blue = (temp & 0x001F);

//	red = (temp & 0xF800) >> 11;
//	green = (temp & 0x7E0) >> 5;
//	blue = (temp & 0x1F);

	red = (red << 3) | (red >> 2);
	green = (green << 2) | (green >> 4);
	blue = (blue << 3) | (blue >> 2);

//	NSLog(@"RGBA Real: %02x%02x%02x", red, green, blue);
//	NSLog(@"RGBA Fake: %x", ((red << 24) | (green << 16) | (blue << 8) | 0xFF));

	return (blue << 16) | (green << 8) | red | 0xFF000000;
//	return (red << 24) | (green << 16) | (blue << 8) | 0xFF;
}

- (NSImage *) convertRGBtoNSImage:(unsigned const char *)data width:(int)width height:(int)height format:(int)format;{
	unsigned short *src;
	unsigned long *dest;
	NSImage* image;
	NSBitmapImageRep *bitmap;
	int dstRowBytes;

	bitmap = [[NSBitmapImageRep alloc]
			  initWithBitmapDataPlanes: nil
			  pixelsWide: width
			  pixelsHigh: height
			  bitsPerSample: 8
			  samplesPerPixel: 4
			  hasAlpha: YES
			  isPlanar: NO
			  colorSpaceName: NSDeviceRGBColorSpace
			  bytesPerRow: width * 4
			  bitsPerPixel: 32];

	src = (unsigned short *) (data);
	dest = (unsigned long *) [bitmap bitmapData];
	dstRowBytes = [bitmap bytesPerRow];

	int i, end = width * height;
	for(i = 0; i < end; i++){
		unsigned short *pixel = src;
		unsigned long destPixel;

		if(format == 3)			destPixel = RGB565toRGBA(*pixel);
		else if(format == 2)	destPixel = RGB555toRGBA(*pixel);
		else if(format == 1)	destPixel = RGB444toRGBA(*pixel);
		else if(format == 0)	destPixel = RGB332toRGBA(*pixel);
		else if(format == 5)	destPixel = *pixel;
		else					destPixel = RGB565toRGBA(*pixel);

		*dest = destPixel;
		dest++;
		src++;
	}

	image = [[NSImage alloc] initWithSize:NSMakeSize(width, height)];
	[image addRepresentation:bitmap];
	[bitmap release];
	
	return image;
}

- (IBAction)openFile:(id)sender{
	// "Standard" open file panel
	NSArray *fileTypes = [NSArray arrayWithObjects:@"jpg", @"gif",@"png", @"psd", @"tga", @"s3dtex", nil];
	int i;
	// Create the File Open Panel class.
	NSOpenPanel* oPanel = [NSOpenPanel openPanel];
//	[oPanel setParentWindow:[sender window]];	// Define the parent of our dialog
//	[oPanel setFloatingPanel:NO];				// When we move our parent window, the dialog moves with it
	[oPanel setCanChooseDirectories:NO];		// Disable the selection of directories in the dialog.
	[oPanel setCanChooseFiles:YES];				// Enable the selection of files in the dialog.
	[oPanel setCanCreateDirectories:YES];		// Enable the creation of directories in the dialog
	[oPanel setAllowsMultipleSelection:NO];		// Allow multiple files selection
	[oPanel setAlphaValue:0.95];				// Alpha value
	[oPanel setTitle:@"Select a file to open"];

	// Display the dialog.  If the OK button was pressed, process the files.
	if([oPanel runModalForDirectory:nil file:nil types:fileTypes] == NSOKButton){
		// Get an array containing the full filenames of all files and directories selected.
		NSArray* files = [oPanel filenames];

		// Loop through all the files and process them.
		for(i = 0; i < [files count]; i++){
			NSString* fileName = [files objectAtIndex:i];
			NSLog(fileName);

			NSString *pathExtension = [[fileName pathExtension] lowercaseString];
			NSLog(@"File: %@", fileName);
			NSLog(@"Type: %@", pathExtension);
			NSImage *imageFromBundle;

			if([pathExtension isEqualToString:@"tga"]){
				NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath: fileName];
				NSData *fileBuffer;

				// Initialize 'TGAHeader'
				[fileHandle seekToFileOffset:0];
				fileBuffer = [fileHandle readDataOfLength:sizeof(TGAHeader)]; // readDataToEndOfFile
				[fileBuffer getBytes:&TGAHeader];

				NSLog(@"Width: %d", TGAHeader.width);
				imageFromBundle = [[NSImage alloc] initWithContentsOfFile: fileName];
				[fileHandle closeFile];
			}
			else if([pathExtension isEqualToString:@"s3dtex"]){
				NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath: fileName];
				NSData *fileBuffer;

				// Initialize 'StexHeader'
				[fileHandle seekToFileOffset:0];
				fileBuffer = [fileHandle readDataOfLength:sizeof(StexHeader)];
				[fileBuffer getBytes:&StexHeader];

				[fileHandle seekToFileOffset:16];
				fileBuffer = [fileHandle readDataToEndOfFile];

				NSLog(@"Width: %d", StexHeader.width);
				NSLog(@"Height: %d", StexHeader.height);
				NSLog(@"RGB Format: %x", StexHeader.rgbFormat);

				imageFromBundle = [self convertRGBtoNSImage:[fileBuffer bytes] width:StexHeader.width height:StexHeader.height format:StexHeader.rgbFormat];
				[fileHandle closeFile];
			}
			else{
				imageFromBundle = [[NSImage alloc] initWithContentsOfFile: fileName];
			}

			if(imageFromBundle != nil){
				if([ViewImage image] != nil) [[ViewImage image] release];
				[ViewImage setImage: imageFromBundle];

				NSRect frame = [MyWindow frame];
				frame.size = [imageFromBundle size];
				if(frame.size.width >= MAX_WIDTH)	frame.size.width = MAX_WIDTH;
				if(frame.size.height >= MAX_HEIGHT)	frame.size.height = MAX_HEIGHT;

				frame.size.width += 80;
				frame.size.height += 150;

				[MyWindow setFrame:frame display:YES animate:YES];
			}
		}
	}
}

@end
