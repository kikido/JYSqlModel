//
//  JYClassInfo.m
//  190611
//
//  Created by dqh on 2019/8/5.
//  Copyright © 2019 duqianhang. All rights reserved.
//

#import "JYClassInfo.h"

static inline JYEncodingType JYEncodingGetType(const char *typeEncoding) {
    char *type = (char *)typeEncoding;
    if (!type) return JYEncodingTypeUnknown;
    size_t len = strlen(type);
    if (len == 0) return JYEncodingTypeUnknown;
    
    JYEncodingType qualifier = 0;
    bool prefix = true;
    while (prefix) {
        switch (*type) {
            case 'r': {
                qualifier |= JYEncodingTypeQualifierConst;
                type++;
            } break;
            case 'n': {
                qualifier |= JYEncodingTypeQualifierIn;
                type++;
            } break;
            case 'N': {
                qualifier |= JYEncodingTypeQualifierInout;
                type++;
            } break;
            case 'o': {
                qualifier |= JYEncodingTypeQualifierOut;
                type++;
            } break;
            case 'O': {
                qualifier |= JYEncodingTypeQualifierBycopy;
                type++;
            } break;
            case 'R': {
                qualifier |= JYEncodingTypeQualifierByref;
                type++;
            } break;
            case 'V': {
                qualifier |= JYEncodingTypeQualifierOneway;
                type++;
            } break;
            default: { prefix = false; } break;
        }
    }
    
    len = strlen(type);
    if (len == 0) return JYEncodingTypeUnknown | qualifier;
    
    switch (*type) {
        case 'v': return JYEncodingTypeVoid | qualifier;
        case 'B': return JYEncodingTypeBool | qualifier;
        case 'c': return JYEncodingTypeInt8 | qualifier;
        case 'C': return JYEncodingTypeUInt8 | qualifier;
        case 's': return JYEncodingTypeInt16 | qualifier;
        case 'S': return JYEncodingTypeUInt16 | qualifier;
        case 'i': return JYEncodingTypeInt32 | qualifier;
        case 'I': return JYEncodingTypeUInt32 | qualifier;
        case 'l': return JYEncodingTypeInt32 | qualifier;
        case 'L': return JYEncodingTypeUInt32 | qualifier;
        case 'q': return JYEncodingTypeInt64 | qualifier;
        case 'Q': return JYEncodingTypeUInt64 | qualifier;
        case 'f': return JYEncodingTypeFloat | qualifier;
        case 'd': return JYEncodingTypeDouble | qualifier;
        case 'D': return JYEncodingTypeLongDouble | qualifier;
        case '#': return JYEncodingTypeClass | qualifier;
        case ':': return JYEncodingTypeSEL | qualifier;
        case '*': return JYEncodingTypeCString | qualifier;
        case '^': return JYEncodingTypePointer | qualifier;
        case '[': return JYEncodingTypeCArray | qualifier;
        case '(': return JYEncodingTypeUnion | qualifier;
        case '{': return JYEncodingTypeStruct | qualifier;
        case '@': {
            if (len == 2 && *(type + 1) == '?')
                return JYEncodingTypeBlock | qualifier;
            else
                return JYEncodingTypeObject | qualifier;
        }
        default: return JYEncodingTypeUnknown | qualifier;
    }
}

@implementation JYClassPropertyInfo
- (instancetype)initWithProperty:(objc_property_t)property
{
    if (!property) return nil;
    
    self = [super init];
    _property = property;
    const char *name = property_getName(property);
    if (name) {
        _name = [NSString stringWithUTF8String:name];
    } else {
        return nil;
    }
    
    JYEncodingType type = 0;
    unsigned int attrCount;
    objc_property_attribute_t *attrs = property_copyAttributeList(property, &attrCount);
    for (unsigned int i = 0; i < attrCount; i++) {
        switch (attrs[i].name[0]) {
            case 'T':
            {
                if (attrs[i].value) {
                    _typeEncoding = [NSString stringWithUTF8String:attrs[i].value];
                    type = JYEncodingGetType(attrs[i].value);
                    
                    if ((type & JYEncodingTypeMask) == JYEncodingTypeObject && _typeEncoding.length) {
                        NSScanner *scanner = [NSScanner scannerWithString:_typeEncoding];
                        if (![scanner scanString:@"@\"" intoString:NULL]) continue;
                        
                        NSString *clsName = nil;
                        if ([scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\"<"] intoString:&clsName]) {
                            if (clsName.length) {
                                _cls = objc_getClass(clsName.UTF8String);
                            }
                        }
                    }
                }
            } break;
                
            case 'V': {
                if (attrs[i].value) {
                    _ivarName = [NSString stringWithUTF8String:attrs[i].value];
                }
            } break;
                
            case 'R':
            {
                type |= JYEncodingTypePropertyReadonly;
            } break;
                
            case 'C':
            {
                type |= JYEncodingTypePropertyCopy;
            } break;
                
            case '&':
            {
                type |= JYEncodingTypePropertyRetain;
            } break;
                
            case 'N':
            {
                type |= JYEncodingTypePropertyNonatomic;
            } break;
                
            case 'D':
            {
                type |= JYEncodingTypePropertyDynamic;
            } break;
                
            case 'W':
            {
                type |= JYEncodingTypePropertyWeak;
            } break;
                
            case 'G':
            {
                type |= JYEncodingTypePropertyCustomGetter;
                if (attrs[i].value) {
                    _getter = NSSelectorFromString([NSString stringWithUTF8String:attrs[i].value]);
                }
            } break;
                
            case 'S':
            {
                type |= JYEncodingTypePropertyCustomSetter;
                if (attrs[i].value) {
                    _setter = NSSelectorFromString([NSString stringWithUTF8String:attrs[i].value]);
                }
            } break;
                
            default:break;
        }
    }
    if (attrs) {
        free(attrs);
        attrs = NULL;
    }
    
    _type = type;
    if (_name.length) {
        if (!_getter) {
            _getter = NSSelectorFromString(_name);
        }
        if (!_setter) {
            _setter = NSSelectorFromString([NSString stringWithFormat:@"set%@%@:", [_name substringToIndex:1].uppercaseString, [_name substringFromIndex:1]]);
        }
    }
    return self;
}

@end

@implementation JYClassInfo {
    BOOL _needUpdate;
}

- (instancetype)initWithClass:(Class)cls
{
    if (!cls) {
        return nil;
    }
    _cls = cls;
    _superCls = class_getSuperclass(cls);
    _isMeta = class_isMetaClass(cls);
    _name = NSStringFromClass(cls);
    
    [self _update];
    _superClassInfo = [self.class classInfoWithClass:_superCls];
    return self;
}

+ (instancetype)classInfoWithClass:(Class)cls
{
    if (!cls) return nil;
    
    static NSMutableDictionary *classCache;
    static NSMutableDictionary *metaCache;
    static dispatch_semaphore_t lock;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        classCache = @{}.mutableCopy;
        metaCache = @{}.mutableCopy;
        lock = dispatch_semaphore_create(1);
    });
    dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
    JYClassInfo *info = class_isMetaClass(cls) ? metaCache[cls] : classCache[cls];
    if (info && info->_needUpdate) {
        [info _update];
    }
    dispatch_semaphore_signal(lock);
    if (!info) {
        info = [[JYClassInfo alloc] initWithClass:cls];
        if (info) {
            dispatch_semaphore_wait(lock, DISPATCH_TIME_FOREVER);
            classCache[cls] = info;
            dispatch_semaphore_signal(lock);
        }
    }
    return info;
}

- (void)_update
{
    _propertyInfos = nil;
    
    Class cls = _cls;
    unsigned int propertyCount;
    objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
    if (properties) {
        NSMutableDictionary *propertyInfos = @{}.mutableCopy;
        for (unsigned int i = 0; i < propertyCount; i++) {
            JYClassPropertyInfo *info = [[JYClassPropertyInfo alloc] initWithProperty:properties[i]];
            if (info.name) {
                propertyInfos[info.name] = info;
            }
        }
        free(properties);
        _propertyInfos = [propertyInfos copy];
    }    
    _needUpdate = false;
}

@end
