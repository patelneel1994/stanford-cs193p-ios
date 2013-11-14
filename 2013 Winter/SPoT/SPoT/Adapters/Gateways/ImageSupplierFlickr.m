//
//  ImageSupplierFlickr.m
//  SPoT
//
//  Created by Hugo Ferreira on 2013/11/07.
//  Copyright (c) 2013 Mindclick. All rights reserved.
//

#import "ImageSupplierFlickr.h"
#import "FlickrFetcher.h"

static NSString * const FlickrTagSeparator = @" ";

@interface ImageSupplierFlickr ()

@property (readonly, nonatomic) NSArray *cachedPhotos;

@end

@implementation ImageSupplierFlickr

#pragma mark - Class

+ (instancetype)sharedImageSupplierFlickr {
    static id sharedInstance = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

#pragma mark - Properties

@synthesize cachedPhotos = _cachedPhotos;

- (NSArray *)cachedPhotos
{
    if (!_cachedPhotos) _cachedPhotos = [FlickrFetcher stanfordPhotos];
    return _cachedPhotos;
}

#pragma mark - Methods

- (NSSet *)uniqueFlickrTags
{
    NSArray *flickrTagsPerPhoto = [self.cachedPhotos valueForKey:FLICKR_TAGS];
    NSArray *allFlickrTagsUsed = [[flickrTagsPerPhoto componentsJoinedByString:FlickrTagSeparator]
                                  componentsSeparatedByString:FlickrTagSeparator];
    return [NSSet setWithArray:allFlickrTagsUsed];
}

- (NSArray *)wrapInTagEntities:(NSSet *)flickrTags
{
    NSMutableArray *tags = [NSMutableArray arrayWithCapacity:[flickrTags count]];
    for (NSString *tagName in flickrTags) {
        NSUInteger numberOfImages = [self countFlickrImagesWithTag:tagName];
        [tags addObject:[[TagEntity alloc] initWithName:tagName imageCount:numberOfImages]];
    }
    return [tags copy];
}

- (NSUInteger)countFlickrImagesWithTag:(NSString *)tagName
{
    return [[self flickrImagesWithTag:tagName] count];
}

- (NSArray *)flickrImagesWithTag:(NSString *)tagName
{
    BOOL(^imageContainsTag)(id, NSUInteger, BOOL*) = ^BOOL(id obj, NSUInteger idx, BOOL *stop) {
        NSRange search = [obj[FLICKR_TAGS] rangeOfString:tagName];
        return search.location != NSNotFound;
    };
    NSIndexSet *matchingImageIndexes = [self.cachedPhotos indexesOfObjectsPassingTest:imageContainsTag];
    return [self.cachedPhotos objectsAtIndexes:matchingImageIndexes];
}

- (NSArray *)wrapInImageEntities:(NSArray *)flickrImages
{
    NSMutableArray *images = [NSMutableArray arrayWithCapacity:[flickrImages count]];
    for (NSDictionary *flickrImage in flickrImages) {
        [images addObject:[[ImageEntity alloc] initWithTitle:flickrImage[FLICKR_PHOTO_TITLE]
                                                 description:[flickrImage valueForKeyPath:FLICKR_PHOTO_DESCRIPTION]
                                                      author:flickrImage[FLICKR_PHOTO_OWNER]
                                                     formats:[self urlsForImage:flickrImage]]];
    }
    return [images copy];
}

- (ImageFormatURLs *)urlsForImage:(NSDictionary *)flickrImage
{
    NSURL *urlNormal = [FlickrFetcher urlForPhoto:flickrImage format:FlickrPhotoFormatLarge];
    NSURL *urlThumb = [FlickrFetcher urlForPhoto:flickrImage format:FlickrPhotoFormatSquare];
    NSURL *urlHires = [FlickrFetcher urlForPhoto:flickrImage format:FlickrPhotoFormatOriginal];
    return [[ImageFormatURLs alloc] initWithURL:urlNormal thumbnail:urlThumb hires:urlHires];
}

#pragma mark - ImageSupplierDataSource

- (NSArray *)listTagsAvailable
{
    return [self wrapInTagEntities:[self uniqueFlickrTags]];
}

- (NSArray *)listTagsExcluding:(NSArray *)tagsToExclude
{
    NSMutableSet *uniqueFlickrTagList = [[self uniqueFlickrTags] mutableCopy];
    for (NSString *excludedTag in tagsToExclude) {
        [uniqueFlickrTagList removeObject:excludedTag];
    }
    return [self wrapInTagEntities:uniqueFlickrTagList];
}	

- (NSArray *)listImagesWithTag:(TagEntity *)tag
{
    return [self wrapInImageEntities:[self flickrImagesWithTag:tag.name]];
}

- (NSArray *)listMax:(NSUInteger)number imagesWithTag:(TagEntity *)tag
{
    return nil;
}

- (NSArray *)listMax:(NSUInteger)number imagesBeforeDate:(NSDate *)date
{
    return nil;
}

@end