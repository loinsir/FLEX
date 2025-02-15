//
//  FLEXPrintLogController.m
//  FLEX
//
//  Created by 김인환 on 2/16/25.
//

#import "FLEXPrintLogController.h"
#import "FLEXSystemLogMessage.h"
#import <fcntl.h>
#import <unistd.h>

@interface FLEXPrintLogController () {
    void (^_newMessagesHandler)(NSArray<FLEXSystemLogMessage *> *);
    int _originalStdOut;
    int _originalStdErr;
    dispatch_source_t _stdoutSource;
    dispatch_source_t _stderrSource;
}

@end

@implementation FLEXPrintLogController

+ (instancetype)withUpdateHandler:(void(^)(NSArray<FLEXSystemLogMessage *> *))newMessagesHandler {
    return [[self alloc] initWithUpdateHandler:newMessagesHandler];
}

- (instancetype)initWithUpdateHandler:(void(^)(NSArray<FLEXSystemLogMessage *> *))newMessagesHandler {
    self = [super init];
    if (self) {
        _newMessagesHandler = [newMessagesHandler copy];
        _messages = [NSMutableArray new];
    }
    return self;
}

- (BOOL)startMonitoring {
    [self captureStdoutAndStderr];
    return YES;
}

- (void)captureStdoutAndStderr {
    _originalStdOut = dup(STDOUT_FILENO);
    _originalStdErr = dup(STDERR_FILENO);

    int stdoutPipe[2];
    int stderrPipe[2];
    pipe(stdoutPipe);
    pipe(stderrPipe);

    dup2(stdoutPipe[1], STDOUT_FILENO);
    dup2(stderrPipe[1], STDERR_FILENO);
    
    close(stdoutPipe[1]);
    close(stderrPipe[1]);

    [self startReadingFromFileDescriptor:stdoutPipe[0] isStdErr:NO];
    [self startReadingFromFileDescriptor:stderrPipe[0] isStdErr:YES];
}

- (void)startReadingFromFileDescriptor:(int)fd isStdErr:(BOOL)isStdErr {
    int fileDescriptor = fcntl(fd, F_SETFL, O_NONBLOCK);
    if (fileDescriptor == -1) return;

    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, fd, 0, queue);
    
    dispatch_source_set_event_handler(source, ^{
        char buffer[1024];
        ssize_t bytesRead = read(fd, buffer, sizeof(buffer) - 1);
        
        if (bytesRead > 0) {
            buffer[bytesRead] = '\0';
            NSString *logMessage = [NSString stringWithUTF8String:buffer];
            [self handleCapturedOutput:logMessage isStdErr:isStdErr];
        }
    });

    dispatch_resume(source);
    
    if (isStdErr) {
        _stderrSource = source;
    } else {
        _stdoutSource = source;
    }
}

- (void)handleCapturedOutput:(NSString *)message isStdErr:(BOOL)isStdErr {
    FLEXSystemLogMessage *logMessage = [FLEXSystemLogMessage logMessageFromDate:[NSDate date] text:message];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.messages addObject:logMessage];

        if (self->_newMessagesHandler) {
            self->_newMessagesHandler(@[logMessage]);
        }
    });
}

- (void)dealloc {
    dup2(_originalStdOut, STDOUT_FILENO);
    dup2(_originalStdErr, STDERR_FILENO);
    
    close(_originalStdOut);
    close(_originalStdErr);

    if (_stdoutSource) {
        dispatch_source_cancel(_stdoutSource);
    }
    if (_stderrSource) {
        dispatch_source_cancel(_stderrSource);
    }
}

@end
