//
//  FLEXPrintLogController.h
//  FLEX
//
//  Created by 김인환 on 2/16/25.
//

#import "FLEXLogController.h"

@interface FLEXPrintLogController : NSObject <FLEXLogController>

+ (instancetype)withUpdateHandler:(void(^)(NSArray<FLEXSystemLogMessage *> *newMessages))newMessagesHandler;
- (BOOL)startMonitoring;

@property (nonatomic) BOOL persistent;
@property (nonatomic) NSMutableArray<FLEXSystemLogMessage *> *messages;

@end
