//
//  ViewController.m
//  FSEventStreamDemo
//
//  Created by 曾文斌 on 2017/7/26.
//  Copyright © 2017年 yww. All rights reserved.
//

#import "ViewController.h"
#import <CoreServices/CoreServices.h>

void fsevents_callback(ConstFSEventStreamRef streamRef,
                       void *userData,
                       size_t numEvents,
                       void *eventPaths,
                       const FSEventStreamEventFlags eventFlags[],
                       const FSEventStreamEventId eventIds[]);

@interface ViewController()

@property(nonatomic) NSInteger syncEventID;
@property(nonatomic, assign) FSEventStreamRef syncEventStream;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
}
#pragma mark - event
- (IBAction)startWatchClicked:(id)sender {
    if(self.syncEventStream) {
        FSEventStreamStop(self.syncEventStream);
        FSEventStreamInvalidate(self.syncEventStream);
        FSEventStreamRelease(self.syncEventStream);
        self.syncEventStream = NULL;
    }
    NSArray *paths = @[@"/Users/yww/Desktop/test"];// 这里填入需要监控的文件夹
    FSEventStreamContext context;
    context.info = (__bridge void * _Nullable)(self);
    context.version = 0;
    context.retain = NULL;
    context.release = NULL;
    context.copyDescription = NULL;
    self.syncEventStream = FSEventStreamCreate(NULL, &fsevents_callback, &context, (__bridge CFArrayRef _Nonnull)(paths), self.syncEventID, 1, kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes);
    FSEventStreamScheduleWithRunLoop(self.syncEventStream, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    FSEventStreamStart(self.syncEventStream);

}
- (IBAction)stopWatchClicked:(id)sender {
    if(self.syncEventStream) {
        FSEventStreamStop(self.syncEventStream);
        FSEventStreamInvalidate(self.syncEventStream);
        FSEventStreamRelease(self.syncEventStream);
        self.syncEventStream = NULL;
    }
}
#pragma mark - private method
-(void)updateEventID {
    self.syncEventID = FSEventStreamGetLatestEventId(self.syncEventStream);
}
#pragma mark - setter
-(void)setSyncEventID:(NSInteger)syncEventID{
    [[NSUserDefaults standardUserDefaults] setInteger:syncEventID forKey:@"SyncEventID"];
}
-(NSInteger)syncEventID {
    NSInteger syncEventID = [[NSUserDefaults standardUserDefaults] integerForKey:@"SyncEventID"];
    if(syncEventID == 0) {
        syncEventID = kFSEventStreamEventIdSinceNow;
    }
    return syncEventID;
}
@end

void fsevents_callback(ConstFSEventStreamRef streamRef,
                       void *userData,
                       size_t numEvents,
                       void *eventPaths,
                       const FSEventStreamEventFlags eventFlags[],
                       const FSEventStreamEventId eventIds[]) {
    ViewController *self = (__bridge ViewController *)userData;
    NSArray *pathArr = (__bridge NSArray*)eventPaths;
    FSEventStreamEventId lastRenameEventID = 0;
    NSString* lastPath = nil;
    for(int i=0; i<numEvents; i++){
        FSEventStreamEventFlags flag = eventFlags[i];
        if(kFSEventStreamEventFlagItemCreated & flag) {
            NSLog(@"create file: %@", pathArr[i]);
        }
        if(kFSEventStreamEventFlagItemRenamed & flag) {
            FSEventStreamEventId currentEventID = eventIds[i];
            NSString* currentPath = pathArr[i];
            if (currentEventID == lastRenameEventID + 1) {
                // 重命名或者是移动文件
                NSLog(@"mv %@ %@", lastPath, currentPath);
            } else {
                // 其他情况, 例如移动进来一个文件, 移动出去一个文件, 移动文件到回收站
                if ([[NSFileManager defaultManager] fileExistsAtPath:currentPath]) {
                    // 移动进来一个文件
                    NSLog(@"move in file: %@", currentPath);
                } else {
                    // 移出一个文件
                    NSLog(@"move out file: %@", currentPath);
                }
            }
            lastRenameEventID = currentEventID;
            lastPath = currentPath;
        }
        if(kFSEventStreamEventFlagItemRemoved & flag) {
            NSLog(@"remove: %@", pathArr[i]);
        }
        if(kFSEventStreamEventFlagItemModified & flag) {
            NSLog(@"modify: %@", pathArr[i]);
        }
    }
    [self updateEventID];
}
