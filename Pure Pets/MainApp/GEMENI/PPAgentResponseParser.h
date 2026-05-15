//
//  PPAgentResponseParser.h
//  PurePets
//
//  Parses the proxy envelope { ok, latencyMs, data: <agent-output> }
//  into a PPAgentMessage. Handles the common Agent Engine response shapes:
//    - String directly
//    - { output | response | answer | text | message | content }
//    - { messages: [ { content/text } ] }   (ADK / LangChain shape)
//    - Tool-call indicators (tool_calls / actions)
//    - Options / suggestions / quick replies
//

#import <Foundation/Foundation.h>
#import "PPAgentMessage.h"

NS_ASSUME_NONNULL_BEGIN

@interface PPAgentResponseParser : NSObject

+ (nullable PPAgentMessage *)parseEnvelope:(NSDictionary *)json
                                     error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
