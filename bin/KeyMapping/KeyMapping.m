#import <Foundation/Foundation.h>

#define checkMinCount(min) {if (count < min) {usage();return 1;}}
#define checkCount(min, max) {if (count < min || count > max) {usage();return 1;}}
void print (NSString *format, ...) NS_FORMAT_FUNCTION(1,2);


NSString *plist;
NSArray *arguments;
NSInteger count;


void print (NSString *format, ...) {
    if (!format) {
        printf("\n");
        return;
    }
    va_list args;
    va_start(args, format);
    printf("%s\n", [[[[NSString alloc] initWithFormat:format arguments:args] stringByReplacingOccurrencesOfString:@"%%" withString:@"%%%%"] UTF8String]);
    va_end(args);
}

void usage() {
	print(@"Edit key-mapping for GPGMail.\n" \
		  "usage: KeyMapping -aeiprs\n" \
		  "    -a pattern keyID ...    Add a mapping for pattern.\n" \
		  "    -s pattern keyID ...    Set mapping for pattern.\n" \
		  "    -r pattern [keyID ...]  Remove mapping(s) for pattern.\n" \
		  "    -p [pattern]            Print mappings (for pattern).\n" \
		  "    -i [file]               Import mappings from file or stdin.\n" \
		  "    -e [file]               Export mapping to file or stdout.");
}

NSMutableDictionary *readMapping() {
	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:plist];
	return [NSMutableDictionary dictionaryWithDictionary:dict[@"KeyMapping"]];
}

void writeMapping(NSDictionary *mapping) {
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:plist];
	dict[@"KeyMapping"] = mapping;
	[dict writeToFile:plist atomically:YES];
}


void addMapping() {
	NSMutableDictionary *mapping = readMapping();
	
	NSMutableSet *values = [NSMutableSet set];
	NSArray *old = mapping[arguments[0]];
	if ([old isKindOfClass:[NSArray class]]) {
		[values addObjectsFromArray:old];
	} else if ([old isKindOfClass:[NSString class]]) {
		[values addObject:old];
	}
	[values addObjectsFromArray:[arguments subarrayWithRange:NSMakeRange(1, count - 1)]];
	
	mapping[arguments[0]] = [values allObjects];
	writeMapping(mapping);
}

void setMapping() {
	NSMutableDictionary *mapping = readMapping();
	mapping[arguments[0]] = [arguments subarrayWithRange:NSMakeRange(1, count - 1)];
	writeMapping(mapping);
}

void removeMapping() {
	NSMutableDictionary *mapping = readMapping();
	NSString *pattern = arguments[0];
	
	if (count == 1) {
		[mapping removeObjectForKey:pattern];
	} else {
		NSMutableSet *values = [NSMutableSet setWithArray:mapping[pattern]];
		for (int i = 1; i < count; i++) {
			[values removeObject:arguments[i]];
		}
		mapping[pattern] = [values allObjects];
	}
	
	writeMapping(mapping);
}

void printMapping() {
	NSDictionary *mapping = readMapping();
	if (count == 1) {
		id values = mapping[arguments[0]];
		if ([values isKindOfClass:[NSArray class]]) {
			values = [values componentsJoinedByString:@" "];
		}
		print(@"%@ %@", arguments[0], values);
	} else {
		for (NSString *key in mapping) {
			id values = mapping[key];
			if ([values isKindOfClass:[NSArray class]]) {
				values = [values componentsJoinedByString:@" "];
			}
			print(@"%@ %@", key, values);
		}
	}
}

void exportMapping() {
	NSDictionary *mapping = readMapping();
	NSMutableString *output = [NSMutableString string];
	
	for (NSString *key in mapping) {
		id values = mapping[key];
		if ([values isKindOfClass:[NSArray class]]) {
			values = [values componentsJoinedByString:@" "];
		}
		[output appendFormat:@"%@ %@\n", key, values];
	}

	if (count == 1) {
		NSError *error = nil;
		[output writeToFile:arguments[0] atomically:NO encoding:NSUTF8StringEncoding error:&error];
		if (error) {
			print(@"Export failed: %@", error);
			exit(3);
		}
	} else {
		printf("%s", [output UTF8String]);
	}
}

void importMapping() {
	NSString *input;
	
	if (count == 1) {
		NSError *error = nil;
		input = [NSString stringWithContentsOfFile:arguments[0] encoding:NSUTF8StringEncoding error:&error];
		if (error) {
			print(@"Import failed: %@", error);
			exit(3);
		}
	} else {
		input = [[NSString alloc] initWithData:[[NSFileHandle fileHandleWithStandardInput] readDataToEndOfFile] encoding:NSUTF8StringEncoding];
	}
	
	NSMutableDictionary *mapping = [NSMutableDictionary dictionary];
	NSArray *lines = [input componentsSeparatedByString:@"\n"];
	for (NSString *line in lines) {
		NSArray *components = [line componentsSeparatedByString:@" "];
		NSUInteger c = components.count;
		if (c > 1) {		
			mapping[components[0]] = [components subarrayWithRange:NSMakeRange(1, c - 1)];
		}
	}
	
	writeMapping(mapping);
}



int main(int argc, const char *argv[]) {
	arguments = [[NSProcessInfo processInfo] arguments];
	count = arguments.count - 2;

	if (count == -1 || [arguments[1] length] > 2) {
		usage();
		return 1;
	}
	
	@try {
		plist = [@"~/Library/Preferences/org.gpgtools.common.plist" stringByExpandingTildeInPath];
		
		NSString *command = arguments[1];
		arguments = [arguments subarrayWithRange:NSMakeRange(2, count)];
		unichar c = [command characterAtIndex:command.length - 1];
		
		switch (c) {
			case 'a':
				checkMinCount(2);
				addMapping();
				break;
			case 's':
				checkMinCount(2);
				setMapping();
				break;
			case 'r':
				checkMinCount(1);
				removeMapping();
				break;
			case 'p':
				checkCount(0, 1);
				printMapping();
				break;
			case 'e':
				checkCount(0, 1);
				exportMapping();
				break;
			case 'i':
				checkCount(0, 1);
				importMapping();
				break;
			default:
				usage();
				return 1;
		}
	}
	@catch (NSException *exception) {
		print(@"Error: %@", exception);
		return 2;
	}
	
    return 0;
}

