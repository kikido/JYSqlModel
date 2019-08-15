//
//  JYClassInfo.h
//  190611
//
//  Created by dqh on 2019/8/5.
//  Copyright © 2019 duqianhang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, JYEncodingType) {
    JYEncodingTypeMask       = 0xFF, ///< mask of type value
    JYEncodingTypeUnknown    = 0, ///< unknown
    JYEncodingTypeVoid       = 1, ///< void
    JYEncodingTypeBool       = 2, ///< bool
    JYEncodingTypeInt8       = 3, ///< char / BOOL
    JYEncodingTypeUInt8      = 4, ///< unsigned char
    JYEncodingTypeInt16      = 5, ///< short
    JYEncodingTypeUInt16     = 6, ///< unsigned short
    JYEncodingTypeInt32      = 7, ///< int
    JYEncodingTypeUInt32     = 8, ///< unsigned int
    JYEncodingTypeInt64      = 9, ///< long long
    JYEncodingTypeUInt64     = 10, ///< unsigned long long
    JYEncodingTypeFloat      = 11, ///< float
    JYEncodingTypeDouble     = 12, ///< double
    JYEncodingTypeLongDouble = 13, ///< long double
    JYEncodingTypeObject     = 14, ///< id
    JYEncodingTypeClass      = 15, ///< Class
    JYEncodingTypeSEL        = 16, ///< SEL
    JYEncodingTypeBlock      = 17, ///< block
    JYEncodingTypePointer    = 18, ///< void*
    JYEncodingTypeStruct     = 19, ///< struct
    JYEncodingTypeUnion      = 20, ///< union
    JYEncodingTypeCString    = 21, ///< char*
    JYEncodingTypeCArray     = 22, ///< char[10] (for example)
    
    JYEncodingTypeQualifierMask   = 0xFF00,   ///< mask of qualifier
    JYEncodingTypeQualifierConst  = 1 << 8,  ///< const
    JYEncodingTypeQualifierIn     = 1 << 9,  ///< in
    JYEncodingTypeQualifierInout  = 1 << 10, ///< inout
    JYEncodingTypeQualifierOut    = 1 << 11, ///< out
    JYEncodingTypeQualifierBycopy = 1 << 12, ///< bycopy
    JYEncodingTypeQualifierByref  = 1 << 13, ///< byref
    JYEncodingTypeQualifierOneway = 1 << 14, ///< oneway
    
    JYEncodingTypePropertyMask         = 0xFF0000, ///< mask of property
    JYEncodingTypePropertyReadonly     = 1 << 16, ///< readonly
    JYEncodingTypePropertyCopy         = 1 << 17, ///< copy
    JYEncodingTypePropertyRetain       = 1 << 18, ///< retain
    JYEncodingTypePropertyNonatomic    = 1 << 19, ///< nonatomic
    JYEncodingTypePropertyWeak         = 1 << 20, ///< weak
    JYEncodingTypePropertyCustomGetter = 1 << 21, ///< getter=
    JYEncodingTypePropertyCustomSetter = 1 << 22, ///< setter=
    JYEncodingTypePropertyDynamic      = 1 << 23, ///< @dynamic
};

typedef NS_ENUM (NSUInteger, JYEncodingNSType) {
    JYEncodingTypeNSUnknown = 0,
    JYEncodingTypeNSString,
    JYEncodingTypeNSMutableString,
    JYEncodingTypeNSValue,
    JYEncodingTypeNSNumber,
    JYEncodingTypeNSDecimalNumber,
    JYEncodingTypeNSData,
    JYEncodingTypeNSMutableData,
    JYEncodingTypeNSDate,
    JYEncodingTypeNSURL,
    JYEncodingTypeNSArray,
    JYEncodingTypeNSMutableArray,
    JYEncodingTypeNSDictionary,
    JYEncodingTypeNSMutableDictionary,
    JYEncodingTypeNSSet,
    JYEncodingTypeNSMutableSet,
};

@interface JYClassPropertyInfo : NSObject
@property (nonatomic, assign, readonly) objc_property_t property;
@property (nonatomic, strong, readonly) NSString *name;
@property (nonatomic, assign, readonly) JYEncodingType type;
@property (nonatomic, strong, readonly) NSString *typeEncoding;
@property (nonatomic, assign, readonly) Class cls;
@property (nonatomic, strong, readonly) NSString *ivarName;
@property (nonatomic, assign, readonly) SEL getter;
@property (nonatomic, assign, readonly) SEL setter;

- (instancetype)initWithProperty:(objc_property_t)property;
@end


@interface JYClassInfo : NSObject
@property (nonatomic, assign) Class cls;
@property (nonatomic, assign, readonly) Class superCls;
@property (nonatomic, assign, readonly) BOOL isMeta;
@property (nonatomic, strong, readonly) NSString *name;
@property (nonatomic, strong, readonly) JYClassInfo *superClassInfo;
@property (nonatomic, strong, readonly) NSDictionary <NSString *, JYClassPropertyInfo *> *propertyInfos;

+ (instancetype)classInfoWithClass:(Class)cls;
@end

NS_ASSUME_NONNULL_END
