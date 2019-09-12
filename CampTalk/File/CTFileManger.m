//
//  CTFileManger.m
//  CampTalk
//
//  Created by renge on 2018/5/9.
//  Copyright © 2018年 yuru. All rights reserved.
//

#import "CTFileManger.h"

@interface CTFileManger ()

@property (nonatomic, assign) NSSearchPathDirectory pathDirectory;
@property (nonatomic, assign) BOOL excludedFromBackup;

@end

@implementation CTFileManger

+ (CTFileManger *)managerWithPathDirectory:(NSSearchPathDirectory)pathDirectory {
    CTFileManger *manager = [[CTFileManger alloc] init];
    manager.pathDirectory = pathDirectory;
    return manager;
}

+ (CTFileManger *)documentManager {
    static CTFileManger *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [self managerWithPathDirectory:NSDocumentDirectory];
    });
    return manager;
}

+ (CTFileManger *)cacheManager {
    static CTFileManger *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [self managerWithPathDirectory:NSCachesDirectory];
        manager.excludedFromBackup = YES;
    });
    return manager;
}

- (BOOL)addSkipBackupAttributeToItemAtURL:(NSURL *)URL {
    assert([[NSFileManager defaultManager] fileExistsAtPath: [URL path]]);
    
    NSError *error = nil;
    BOOL success = [URL setResourceValue:[NSNumber numberWithBool:self.excludedFromBackup]
                                  forKey:NSURLIsExcludedFromBackupKey error:&error];
    if(!success){
        NSLog(@"Error excluding %@ from backup %@", [URL lastPathComponent], error);
    }
    return success;
}

//获取Documents目录
- (NSString *)basePath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(self.pathDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return documentsDirectory;
}

- (NSString *)userBasePath {
    assert(self.user.length > 0);
    NSString *documentsDirectory = [self.basePath stringByAppendingPathComponent:self.user];
    [self createFolderWithPath:documentsDirectory];
    return documentsDirectory;
}

- (NSString *)pathWithFolderName:(NSString *)folderName {
    NSString *documentsPath = [self userBasePath];
    NSString *directory = [documentsPath stringByAppendingPathComponent:folderName];
    return directory;
}

- (NSString *)createFolderWithName:(NSString *)folder {
    NSString *directory = [self pathWithFolderName:folder];
    return [self createFolderWithPath:directory];
}

- (NSString *)createFolderWithPath:(NSString *)directory {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    BOOL res = [fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:&error];
    if (res) {
        if (self.excludedFromBackup) {
            [self addSkipBackupAttributeToItemAtURL:[NSURL fileURLWithPath:directory]];
        }
    } else {
        NSLog(@"failed--> %@", error);
    }
    return res ? directory : nil;
}

- (NSString *)pathWithFileName:(NSString *)fileName folderName:(NSString *)folderName {
    NSString *directory = [self pathWithFolderName:folderName];
    NSString *path = [directory stringByAppendingPathComponent:fileName];
    return path;
}

- (NSString *)fileExistedWithFileName:(NSString *)fileName folderName:(NSString *)folderName {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *path = [self pathWithFileName:fileName folderName:folderName];
    if ([fileManager fileExistsAtPath:path]) {
        return path;
    } else {
        return nil;
    }
}

- (NSString *)createFile:(NSString *)fileName atFolder:(NSString *)folderName data:(NSData *)data {
    NSString *path = [self pathWithFileName:fileName folderName:folderName];
    [self createFolderWithPath:[path stringByDeletingLastPathComponent]];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL res = [fileManager createFileAtPath:path contents:data attributes:nil];
    if (res) {
        if (self.excludedFromBackup) {
            [self addSkipBackupAttributeToItemAtURL:[NSURL fileURLWithPath:path]];
        }
    } else {
        NSLog(@"failed");
    }
    return res ? path : nil;
}

- (NSString *)createFile:(NSString *)fileName extension:(NSString *)extension atFolder:(NSString *)folderName data:(NSData *)data {
    NSString *format = nil;
    if (extension.length && [extension characterAtIndex:0] == '.') {
        format = @"%@";
    } else {
        format = @".%@";
    }
    return [self createFile:[fileName stringByAppendingFormat:format, extension] atFolder:folderName data:data];
}

- (BOOL)existedAtPath:(NSString *)path {
    return [self existedAtPath:path isDirectory:nil];
}

- (BOOL)existedAtPath:(NSString *)path isDirectory:(nullable BOOL *)isDirectory {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    return [fileManager fileExistsAtPath:path isDirectory:isDirectory];
}

@end
