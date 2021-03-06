#import "BasePost.h"
#import "Media.h"
#import "NSMutableDictionary+Helpers.h"
#import "ContextManager.h"
#import <WordPressShared/NSString+Util.h>
#import <WordPressShared/NSString+XMLExtensions.h>
#import "NSString+Helpers.h"

static const NSUInteger PostDerivedSummaryLength = 150;

NSString * const PostStatusDraft = @"draft";
NSString * const PostStatusPending = @"pending";
NSString * const PostStatusPrivate = @"private";
NSString * const PostStatusPublish = @"publish";
NSString * const PostStatusScheduled = @"future";
NSString * const PostStatusTrash = @"trash";
NSString * const PostStatusDeleted = @"deleted"; // Returned by wpcom REST API when a post is permanently deleted.

@implementation BasePost

@dynamic authorID;
@dynamic author;
@dynamic authorAvatarURL;
@dynamic content;
@dynamic date_created_gmt;
@dynamic dateModified;
@dynamic postID;
@dynamic postTitle;
@dynamic status;
@dynamic password;
@dynamic remoteStatusNumber;
@dynamic permaLink;
@dynamic mt_excerpt;
@dynamic mt_text_more;
@dynamic wp_slug;
@dynamic post_thumbnail;
@dynamic pathForDisplayImage;

@synthesize isFeaturedImageChanged;

+ (NSString *)titleForStatus:(NSString *)status
{
    if ([status isEqualToString:PostStatusDraft]) {
        return NSLocalizedString(@"Draft", @"Name for the status of a draft post.");

    } else if ([status isEqualToString:PostStatusPending]) {
        return NSLocalizedString(@"Pending review", @"Name for the status of a post pending review.");

    } else if ([status isEqualToString:PostStatusPrivate]) {
        return NSLocalizedString(@"Privately published", @"Name for the status of a post that is marked private.");

    } else if ([status isEqualToString:PostStatusPublish]) {
        return NSLocalizedString(@"Published", @"Name for the status of a published post.");

    } else if ([status isEqualToString:PostStatusTrash]) {
        return NSLocalizedString(@"Trashed", @"Name for the status of a trashed post");

    } else if ([status isEqualToString:PostStatusScheduled]) {
        return NSLocalizedString(@"Scheduled", @"Name for the status of a scheduled post");
    }

    return status;
}

+ (NSString *)summaryFromContent:(NSString *)string
{
    string = [NSString makePlainText:string];
    string = [NSString stripShortcodesFromString:string];
    string = [string stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\n"]];
    return [string stringByEllipsizingWithMaxLength:PostDerivedSummaryLength preserveWords:YES];
}

- (NSString *)availableStatusForPublishOrScheduled
{
    if ([self hasFuturePublishDate]) {
        return PostStatusScheduled;
    }
    return PostStatusPublish;
}

- (NSArray *)availableStatusesForEditing
{
    // Note: Read method description before changing values.
    return @[PostStatusDraft,
             PostStatusPending,
             [self availableStatusForPublishOrScheduled]];
}

- (BOOL)hasNeverAttemptedToUpload
{
    return self.remoteStatus == AbstractPostRemoteStatusLocal;
}

- (BOOL)hasLocalChanges
{
    return self.remoteStatus == AbstractPostRemoteStatusLocal || self.remoteStatus == AbstractPostRemoteStatusFailed;
}

- (BOOL)hasRemote
{
    return ((self.postID != nil) && ([self.postID longLongValue] > 0));
}

- (void)remove
{
    if (self.remoteStatus == AbstractPostRemoteStatusPushing || self.remoteStatus == AbstractPostRemoteStatusLocal) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"PostUploadCancelled" object:self];
    }
    
    [self.managedObjectContext performBlock:^{
        [self.managedObjectContext deleteObject:self];
    }];

}

- (void)save
{
    [[ContextManager sharedInstance] saveContext:self.managedObjectContext];
}

- (NSString *)statusTitle
{
    return [BasePost titleForStatus:self.status];
}

// This is different than isScheduled. See .h for details.
- (BOOL)hasFuturePublishDate
{
    if (!self.date_created_gmt) {
        return NO;
    }
    return (self.date_created_gmt == [self.date_created_gmt laterDate:[NSDate date]]);
}

// If the post has a scheduled status.
- (BOOL)isScheduled
{
    return ([self.status isEqualToString:PostStatusScheduled]);
}

- (AbstractPostRemoteStatus)remoteStatus
{
    return (AbstractPostRemoteStatus)[[self remoteStatusNumber] intValue];
}

- (void)setRemoteStatus:(AbstractPostRemoteStatus)aStatus
{
    [self setRemoteStatusNumber:[NSNumber numberWithInt:aStatus]];
}

+ (NSString *)titleForRemoteStatus:(NSNumber *)remoteStatus
{
    switch ([remoteStatus intValue]) {
        case AbstractPostRemoteStatusPushing:
            return NSLocalizedString(@"Uploading", @"");
        case AbstractPostRemoteStatusFailed:
            return NSLocalizedString(@"Failed", @"");
        case AbstractPostRemoteStatusSync:
            return NSLocalizedString(@"Posts", @"");
        default:
            return NSLocalizedString(@"Local", @"");
    }
}

- (NSString *)remoteStatusText
{    
    return [BasePost titleForRemoteStatus:self.remoteStatusNumber];
}

- (NSDate *)dateCreated
{
    return self.date_created_gmt;
}

- (BOOL)dateCreatedIsNilOrEqualToDateModified
{
    return self.date_created_gmt == nil || [self.date_created_gmt isEqualToDate:self.dateModified];
}

- (void)setDateCreated:(NSDate *)localDate
{
    self.date_created_gmt = localDate;

    /*
     If the date is nil it means publish immediately so set the status to publish.
     If the date is in the future set the status to scheduled if current status is published.
     If the date is now or in the past, and the status is scheduled, set the status
     to published.
     */
    if ([self dateCreatedIsNilOrEqualToDateModified]) {
        // A nil date means publish immediately.
        self.status = PostStatusPublish;

    } else if ([self hasFuturePublishDate]) {
        // Needs to be a nested conditional so future date + scheduled status
        // is handled correctly.
        if ([self.status isEqualToString:PostStatusPublish]) {
            self.status = PostStatusScheduled;
        }
    } else if ([self.status isEqualToString:PostStatusScheduled]) {
        self.status = PostStatusPublish;
    }
}

- (void)findComments
{
}


#pragma mark - PostContentProvider protocol

- (NSString *)titleForDisplay
{
    NSString *title = [self.postTitle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if (title == nil || ([title length] == 0)) {
        title = NSLocalizedString(@"(no title)", @"");
    }
    return [title stringByDecodingXMLCharacters];
}

- (NSString *)authorForDisplay
{
    return self.author;
}

- (NSString *)blogNameForDisplay
{
    return @"";
}

- (NSString *)contentForDisplay
{
    return self.content;
}

- (NSString *)contentPreviewForDisplay
{
    return self.content;
}

- (NSString *)gravatarEmailForDisplay
{
    return nil;
}

- (NSURL *)avatarURLForDisplay
{
    return nil;
}

- (NSDate *)dateForDisplay
{
    return [self dateCreated];
}

- (NSString *)statusForDisplay
{
    if (self.remoteStatus == AbstractPostRemoteStatusSync) {
        if ([self.status isEqualToString:PostStatusPublish] || [self.status isEqualToString:PostStatusDraft]) {
            return [NSString string];
        }
        return self.statusTitle;
    }

    if (self.remoteStatus == AbstractPostRemoteStatusPushing) {
        return NSLocalizedString(@"Uploading...", @"Status displayed for a post being uploaded");
    }
    return [AbstractPost titleForRemoteStatus:@((int)self.remoteStatus)];
}

@end
