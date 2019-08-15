//
//  JYSqlModel.m
//  190611
//
//  Created by dqh on 2019/8/5.
//  Copyright © 2019 duqianhang. All rights reserved.
//

#import "JYSqlModel.h"
#import "JYClassInfo.h"
#import <FMDB.h>
#import <objc/message.h>


NSString *const JYColumnConstraintKeyNotNull = @"notNull";
NSString *const JYColumnConstraintKeyDefault = @"default";
NSString *const JYColumnConstraintKeyDefaultValue = @"defaultValue";
NSString *const JYColumnConstraintKeyUnique = @"unique";
NSString *const JYColumnConstraintKeyPrimaryKey = @"primaryKey";
NSString *const JYColumnConstraintKeyAutoIncrement = @"autoincrement";

static BOOL jySqlModeDebugEnable = false;
#ifndef __OPTIMIZE__
#define JYSqlModelLog(format, ...) if (jySqlModeDebugEnable) printf("\n[%s] %s [第%d行] %s\n", __TIME__, __FUNCTION__, __LINE__, [[NSString stringWithFormat:format, ## __VA_ARGS__] UTF8String]);
#else
#define JYSqlModelLog(...) {}
#endif

typedef NS_OPTIONS(NSUInteger, JYColumnConstraintType) {
    JYColumnConstraintTypeNone              = 0,
    JYColumnConstraintTypeNotNull           = 1 << 0,
    JYColumnConstraintTypeDefault           = 1 << 1,
    JYColumnConstraintTypeUnique            = 1 << 2,
    JYColumnConstraintTypePrimaryKey        = 1 << 3,
    JYColumnConstraintTypeAutoIncrement     = 1 << 4
};

typedef NS_ENUM (NSUInteger, JYColumnType) {
    JYColumnTypeUnknow = 0,
    JYColumnTypeInteger,    // c的整型，NSNumber @"integer"
    JYColumnTypeReal,       // c的浮点型，NSDecimalNumber @"real"
    JYColumnTypeText,       // NSString，NSMutableString，NSURL, @"text"
    JYColumnTypeBlob,       // NSData，NSMutableData
    JYColumnTypeDate,       // NSDate @"date"
    JYColumnTypeBool        // c的bool @"bool"
};

@interface _JYSqlColumnModel : NSObject {
    @package
    NSString *_name;
    JYColumnType _columnType;
    JYColumnConstraintType _constraintType;
    id _defaultValue;
}
@end

@implementation _JYSqlColumnModel
@end

static inline __attribute__((always_inline)) _JYSqlColumnModel * JYGetColumnMode(FMResultSet *resultSet) {
    NSString *colName = [resultSet stringForColumn:@"name"];
    const unsigned char *type = [resultSet UTF8StringForColumn:@"type"];
    BOOL notNull = [resultSet boolForColumn:@"notnull"];
    BOOL pk = [resultSet boolForColumn:@"pk"];
    id defaultValue = [resultSet objectForColumn:@"dflt_value"];
    
//    JYSqlModelLog(@"字段%@，类型%s", colName, type);
    _JYSqlColumnModel *colMode = [_JYSqlColumnModel new];
    JYColumnConstraintType constraintType = 0;
    if (notNull) constraintType |= JYColumnConstraintTypeNotNull;
    if (pk) constraintType |= JYColumnConstraintTypePrimaryKey;
    colMode->_defaultValue = defaultValue;
    colMode->_constraintType = constraintType;
    colMode->_name = colName;
    JYColumnType colType = 0;
    
    switch (type[0]) {
        case 'r':
        case 'R':
            colType = JYColumnTypeReal;
            break;
            
        case 'i':
        case 'I':
            colType = JYColumnTypeInteger;
            break;
            
        case 'b':
        case 'B':
            if (*(type + 1) == 'l' || *(type + 1) == 'L') {
                colType = JYColumnTypeBlob;
            } else {
                colType = JYColumnTypeBool;
            }
            break;
            
        case 'd':
        case 'D':
            colType = JYColumnTypeDate;
            break;
            
        case 't':
        case 'T':
            colType = JYColumnTypeText;
            break;
            
        default:
            colType = JYColumnTypeUnknow;
            break;
    }
    colMode->_columnType = colType;
    return colMode;
}

/** 判断是否是foundation框架的类 */
static inline JYEncodingNSType JYClassGetNSType(Class cls) {
    if (!cls) return JYEncodingTypeNSUnknown;
    if ([cls isSubclassOfClass:[NSMutableString class]]) return JYEncodingTypeNSMutableString;
    if ([cls isSubclassOfClass:[NSString class]]) return JYEncodingTypeNSString;
    if ([cls isSubclassOfClass:[NSDecimalNumber class]]) return JYEncodingTypeNSDecimalNumber;
    if ([cls isSubclassOfClass:[NSNumber class]]) return JYEncodingTypeNSNumber;
    if ([cls isSubclassOfClass:[NSValue class]]) return JYEncodingTypeNSValue;
    if ([cls isSubclassOfClass:[NSMutableData class]]) return JYEncodingTypeNSMutableData;
    if ([cls isSubclassOfClass:[NSData class]]) return JYEncodingTypeNSData;
    if ([cls isSubclassOfClass:[NSDate class]]) return JYEncodingTypeNSDate;
    if ([cls isSubclassOfClass:[NSURL class]]) return JYEncodingTypeNSURL;
    if ([cls isSubclassOfClass:[NSMutableArray class]]) return JYEncodingTypeNSMutableArray;
    if ([cls isSubclassOfClass:[NSArray class]]) return JYEncodingTypeNSArray;
    if ([cls isSubclassOfClass:[NSMutableDictionary class]]) return JYEncodingTypeNSMutableDictionary;
    if ([cls isSubclassOfClass:[NSDictionary class]]) return JYEncodingTypeNSDictionary;
    if ([cls isSubclassOfClass:[NSMutableSet class]]) return JYEncodingTypeNSMutableSet;
    if ([cls isSubclassOfClass:[NSSet class]]) return JYEncodingTypeNSSet;
    return JYEncodingTypeNSUnknown;
}

/** 判断是否是c数字类型 */
static inline BOOL JYEncodingTypeIsCNumber(JYEncodingType type) {
    switch (type & JYEncodingTypeMask) {
        case JYEncodingTypeBool:
        case JYEncodingTypeInt8:
        case JYEncodingTypeUInt8:
        case JYEncodingTypeInt16:
        case JYEncodingTypeUInt16:
        case JYEncodingTypeInt32:
        case JYEncodingTypeUInt32:
        case JYEncodingTypeInt64:
        case JYEncodingTypeUInt64:
        case JYEncodingTypeFloat:
        case JYEncodingTypeDouble:
        case JYEncodingTypeLongDouble: return YES;
        default: return NO;
    }
}

static inline JYColumnType JYColumnGetType(BOOL isCNumber, JYEncodingType type, JYEncodingNSType nsType) {
    if (isCNumber) {
        switch (type & JYEncodingTypeMask) {
            case JYEncodingTypeBool:
                return JYColumnTypeBool;break;
                
            case JYEncodingTypeInt8:
            case JYEncodingTypeUInt8:
            case JYEncodingTypeInt16:
            case JYEncodingTypeUInt16:
            case JYEncodingTypeInt32:
            case JYEncodingTypeUInt32:
            case JYEncodingTypeInt64:
            case JYEncodingTypeUInt64:
                return JYColumnTypeInteger;break;
                
            case JYEncodingTypeFloat:
            case JYEncodingTypeDouble:
            case JYEncodingTypeLongDouble:
                return JYColumnTypeReal;break;
                
            default:
                return JYColumnTypeUnknow;break;
        }
    }
    
    switch (nsType) {
        case JYEncodingTypeNSUnknown:
            return JYColumnTypeUnknow;break;
            
        case JYEncodingTypeNSValue:
        case JYEncodingTypeNSDecimalNumber:
            return JYColumnTypeReal;break;
            
        case JYEncodingTypeNSNumber:
            return JYColumnTypeInteger;break;
            
        case JYEncodingTypeNSString:
        case JYEncodingTypeNSMutableString:
        case JYEncodingTypeNSURL:
            return JYColumnTypeText;break;
            
        case JYEncodingTypeNSData:
        case JYEncodingTypeNSMutableData:
            return JYColumnTypeBlob;break;
            
        case JYEncodingTypeNSDate:
            return JYColumnTypeDate;break;
            
        default:
            return JYColumnTypeUnknow;break;
    }
    return JYColumnTypeUnknow;
}

/** 根据字段类别得到字段的类型 */
static inline NSString * JYGetColumnTypeDescription(JYColumnType colType, NSString *propertyName) {
    switch (colType) {
        case JYColumnTypeUnknow:
            @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"属性%@的类别不能被识别", propertyName] userInfo:nil];
            break;
        case JYColumnTypeInteger:
            return @"integer";break;
        case JYColumnTypeReal:
            return @"real";break;
        case JYColumnTypeText:
            return @"text";break;
        case JYColumnTypeBlob:
            return @"blob";break;
        case JYColumnTypeDate:
            return @"date";break;
        case JYColumnTypeBool:
            return @"bool";break;
        default:
            break;
    }
    @throw [NSException exceptionWithName:NSInvalidArgumentException reason:[NSString stringWithFormat:@"属性%@的类别不能被识别", propertyName] userInfo:nil];
}

static inline NSString * JYGetColumnConstraintDescription(_JYSqlColumnModel *colMode) {
    NSMutableString *result = [NSMutableString string];
    JYColumnConstraintType type = colMode->_constraintType;
    if (type & JYColumnConstraintTypeNotNull) {
        [result appendString:@"not null "];
    }
    if (type & JYColumnConstraintTypeDefault) {
        [result appendFormat:@"default %@ ", colMode->_defaultValue];
    }
    if (type & JYColumnConstraintTypeUnique) {
        [result appendString:@"unique "];
    }
    if (type & JYColumnConstraintTypePrimaryKey) {
        [result appendString:@"primary key "];
    }
    if (type & JYColumnConstraintTypeAutoIncrement) {
        [result appendString:@"autoincrement "];
    }
    return result;
}

/** 设置字段的约束条件 */
static inline void JYColumnModeSetConstraintType(_JYSqlColumnModel *colMode, NSDictionary *dict) {
    if (!colMode || !dict) return;
    
    JYColumnConstraintType type = 0;
    if ([dict[JYColumnConstraintKeyNotNull] boolValue]) {
        type |= JYColumnConstraintTypeNotNull;
    }
    if ([dict[JYColumnConstraintKeyDefault] boolValue] && dict[JYColumnConstraintKeyDefaultValue]) {
        type |= JYColumnConstraintTypeDefault;
        colMode->_defaultValue = dict[JYColumnConstraintKeyDefaultValue];
    }
    if ([dict[JYColumnConstraintKeyUnique] boolValue]) {
        type |= JYColumnConstraintTypeUnique;
    }
    if ([dict[JYColumnConstraintKeyPrimaryKey] boolValue]) {
        type |= JYColumnConstraintTypePrimaryKey;
    }
    if ([dict[JYColumnConstraintKeyAutoIncrement] boolValue]) {
        type |= JYColumnConstraintTypeAutoIncrement;
    }
    colMode->_constraintType = type;
}

@interface _JYSqlModellPropertyMeta : NSObject {
    @package
    NSString *_name;
    JYEncodingType _type;
    JYEncodingNSType _nsType;
    BOOL _isCNumber;
    JYClassPropertyInfo *_info;
    Class _cls;
    _JYSqlColumnModel *_columnMode;
    NSString *_mapperColumn;
    SEL _getter;
    SEL _setter;
}
@end

@implementation _JYSqlModellPropertyMeta
+ (instancetype)metaWithClassInfo:(JYClassInfo *)classInfo propertyInfo:(JYClassPropertyInfo *)propertyInfo
{
    _JYSqlModellPropertyMeta *meta = [self new];
    meta->_name = propertyInfo.name;
    meta->_mapperColumn = propertyInfo.name;
    meta->_type = propertyInfo.type;
    meta->_info = propertyInfo;
    
    if ((meta->_type & JYEncodingTypeMask) == JYEncodingTypeObject) {
        meta->_nsType = JYClassGetNSType(propertyInfo.cls);
    } else {
        meta->_isCNumber = JYEncodingTypeIsCNumber(meta->_type);
    }
    meta->_cls = propertyInfo.cls;
    
    if (propertyInfo.getter && [classInfo.cls instancesRespondToSelector:propertyInfo.getter]) {
        meta->_getter = propertyInfo.getter;
    }
    if (propertyInfo.setter && [classInfo.cls instancesRespondToSelector:propertyInfo.setter]) {
        meta->_setter = propertyInfo.setter;
    }
    
    _JYSqlColumnModel *colMode = [_JYSqlColumnModel new];
    colMode->_name = propertyInfo.name;
    colMode->_columnType = JYColumnGetType(meta->_isCNumber, meta->_type, meta->_nsType);
    meta->_columnMode = colMode;
    
    return meta;
}
@end

@interface _JYSqlModelMeta : NSObject {
    @package
    JYClassInfo *_classInfo;
    NSDictionary<NSString *, _JYSqlModellPropertyMeta *> *_mapper;
}
@end


@implementation _JYSqlModelMeta
- (instancetype)initWithClass:(Class)cls
{
    JYClassInfo *classInfo = [JYClassInfo classInfoWithClass:cls];
    if (!classInfo) return nil;
    
    self = [super init];
    
    NSMutableDictionary *propertyMetas = @{}.mutableCopy;
    JYClassInfo *curClassInfo = classInfo;
    while (curClassInfo && curClassInfo.superCls != nil) {
        for (JYClassPropertyInfo *propertyInfo in curClassInfo.propertyInfos.allValues) {
            if (!propertyInfo.name) continue;
            
            _JYSqlModellPropertyMeta *meta = [_JYSqlModellPropertyMeta metaWithClassInfo:curClassInfo propertyInfo:propertyInfo];
            if (!meta || !meta->_name) continue;
            if (!meta->_getter || !meta->_setter) continue;
            if (propertyMetas[meta->_name]) continue;
            
            propertyMetas[meta->_name] = meta;
        }
        curClassInfo = curClassInfo.superClassInfo;
    }
    
    // 自定义属性和字段之间的映射关系。注意：属性和字段名都需要唯一
    if ([cls respondsToSelector:@selector(jyCustomPropertyMapper)]) {
        NSDictionary *customMapper = [(id<JYSqlModel>)cls jyCustomPropertyMapper];
        [customMapper enumerateKeysAndObjectsUsingBlock:^(NSString *propertyName, NSString *colName, BOOL * _Nonnull stop) {
            _JYSqlModellPropertyMeta *propertyMeta = propertyMetas[propertyName];
            if (!propertyMeta) return;
            
            if ([colName isKindOfClass:[NSString class]] && colName.length) {
                propertyMeta->_mapperColumn = colName;
                propertyMeta->_columnMode->_name = colName;
            }
        }];
    }
    
    // 自定义字段约束条件
    if ([cls respondsToSelector:@selector(jyCustomPropertyConstraint)]) {
        NSDictionary *constrantMapper = [(id<JYSqlModel>)cls jyCustomPropertyConstraint];
        [constrantMapper enumerateKeysAndObjectsUsingBlock:^(NSString *propertyName, NSDictionary *obj, BOOL * _Nonnull stop) {
            _JYSqlModellPropertyMeta *meta = propertyMetas[propertyName];
            if (!meta) return;
            
            _JYSqlColumnModel *coloMode = meta->_columnMode;
            JYColumnModeSetConstraintType(coloMode, obj);
        }];
    }
    
    if (propertyMetas.count) _mapper = [propertyMetas copy];
    _classInfo = classInfo;
    return self;
}
@end

static bool JY_CreateNewSql(NSString *tbName, NSDictionary<NSString *, _JYSqlModellPropertyMeta *> *columnModes, FMDatabaseQueue *db) {
    __block NSString *colType = nil;
    __block NSString *constraintType = nil;
    NSMutableString *createSql = [NSMutableString stringWithFormat:@"create table if not exists %@ (", tbName];
    [columnModes enumerateKeysAndObjectsUsingBlock:^(NSString *propertyName, _JYSqlModellPropertyMeta *propertyMeta, BOOL * _Nonnull stop) {
        if (!propertyMeta->_name) return;
        // 确定column的类别
        colType = JYGetColumnTypeDescription(propertyMeta->_columnMode->_columnType, propertyMeta->_name);
        // 确定column的约束
        constraintType = JYGetColumnConstraintDescription( propertyMeta->_columnMode);
        
        [createSql appendFormat:@"%@ %@ %@,", propertyMeta->_mapperColumn, colType, constraintType];
    }];
    if (columnModes.count) {
        [createSql replaceCharactersInRange:NSMakeRange(createSql.length-1, 1) withString:@")"];
    } else {
        [createSql appendString:@")"];
    }
    JYSqlModelLog(@"创建表 %@", createSql);
    __block BOOL result = false;
    [db inDatabase:^(FMDatabase * _Nonnull db) {
        [db executeUpdate:createSql];
    }];
    return result;
}

@implementation JYSqlModel
+ (NSString *)tbName
{
    @throw [NSException exceptionWithName:NSObjectNotAvailableException reason:@"需要子类重载该方法" userInfo:nil];
}

+ (NSString *)dbFilePath
{
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/JyDb.sqlite"];
}

+ (BOOL)debugLogEnabled
{
    return YES;
}

static inline FMDatabaseQueue * JYGetDataBase(NSString *path) {
    static FMDatabaseQueue *dataBase = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dataBase = [FMDatabaseQueue databaseQueueWithPath:path];
    });
    return dataBase;
}

static inline _JYSqlModelMeta * JYGetModeMeta(Class cls) {
    static CFMutableDictionaryRef cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    });
    _JYSqlModelMeta *meta = CFDictionaryGetValue(cache, (__bridge const void *)(cls));
    if (!meta) {
        meta = [[_JYSqlModelMeta alloc] initWithClass:cls];
        if (meta) {
            CFDictionarySetValue(cache, (__bridge const void *)(cls), (__bridge const void *)(meta));
        }
        if (!meta->_mapper.count) return nil;
    }
    return meta;
}

static inline NSString * JYGetPrimaryKey(Class cls) {
    static CFMutableDictionaryRef cache;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = CFDictionaryCreateMutable(CFAllocatorGetDefault(), 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    });
    __block NSString *key = CFDictionaryGetValue(cache, (__bridge const void *)(cls));
    if (!key) {
        _JYSqlModelMeta *meta = JYGetModeMeta(cls);
        [meta->_mapper enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull propertyName, _JYSqlModellPropertyMeta * _Nonnull obj, BOOL * _Nonnull stop) {
            if (obj->_columnMode->_constraintType & JYColumnConstraintTypePrimaryKey) {
                key = obj->_mapperColumn;
                *stop = true;
            }
        }];
        if (key) {
            CFDictionarySetValue(cache, (__bridge const void *)(cls), (__bridge const void *)(key));
        } else {
            CFDictionarySetValue(cache, (__bridge const void *)(cls), (__bridge const void *)(@"jy_nokey"));
        }
    }
    return [key isEqualToString:@"jy_nokey"] ? nil : key;
}

+ (void)load
{
    jySqlModeDebugEnable = [self debugLogEnabled];
    
    // 找到该类的所有子类
    // 使用该方法消耗较大
    // 貌似可以使用 class 的成员变量 firstSubclass 和 nextSiblingClass 来直接查找，但是我找不到直接使用这两个成员变量的方法。。。
    int numCls = objc_getClassList(NULL, 0);
    if (numCls <= 0) return;
    
    NSMutableArray *allSubCls = @[].mutableCopy;
    Class *classes = (Class *)malloc(sizeof(Class) * numCls);
    objc_getClassList(classes, numCls);
    
    for (int i = 0; i < numCls; i++) {
        if (self == class_getSuperclass(classes[i])) {
            [allSubCls addObject:classes[i]];
        }
    }
    free(classes);
    if (!allSubCls.count) return;
    
    
    // 如果想自定义db地址，就自己改下 dbFilePath 这个方法的返回值
    FMDatabaseQueue *dataBase = JYGetDataBase([self dbFilePath]);
    NSString *sql = nil;
    
    // 遍历子类，创建相应的model meta，创建缓存
    NSMutableSet *existTBNames = [NSMutableSet set];
    for (Class subCls in allSubCls) {
        NSString *tbName = [subCls tbName];
        NSAssert(tbName.length, @"表名不能为空");
        NSAssert(![existTBNames containsObject:tbName], @"表名不能重复");
        [existTBNames addObject:tbName];
        
        _JYSqlModelMeta *meta = JYGetModeMeta(subCls);
        if (!meta) return;
        
        // 判断表是否存在
        __block BOOL isTbExist = false;
        sql = [NSString stringWithFormat:@"select count(*) from sqlite_master where type='table' and name like '%@'", tbName];
        [dataBase inDatabase:^(FMDatabase * _Nonnull db) {
            FMResultSet *result = [db executeQuery:sql];
            while ([result next]) {
                int num = [result intForColumnIndex:0];
                if (num) isTbExist = true;
            }
        }];
        
        if (!isTbExist) {
            JY_CreateNewSql(tbName, meta->_mapper, dataBase);
        } else {
            // 1. 表已经存在，获取旧表所有字段的信息
            // 2. 与model的属性比较，如果字段的类型改变，或者某些字段不用了，则数据迁移到新表中。
            // 3. 判断是否需要添加新的字段
            
            // column -> _JYSqlColumnModel
            NSMutableDictionary *sqlAllColumns = @{}.mutableCopy;
            sql = [NSString stringWithFormat:@"PRAGMA table_info(%@)", tbName];
            [dataBase inDatabase:^(FMDatabase * _Nonnull db) {
                FMResultSet *result = [db executeQuery:sql];
                while ([result next]) {
                    _JYSqlColumnModel *colMode = JYGetColumnMode(result);
                    if ([colMode->_name length]) sqlAllColumns[colMode->_name] = colMode;
                }
            }];
            
            __block BOOL needRemoval = false;
            NSMutableArray *addArray = @[].mutableCopy;
            NSMutableArray *existColumns = @[].mutableCopy;
            
            // model中的所有属性 propertyName -> _JYSqlModellPropertyMeta
            [meta->_mapper enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull propertyName, _JYSqlModellPropertyMeta * _Nonnull obj, BOOL * _Nonnull stop) {
                // 判断一个字段是否对应了多个属性
                // 字段和属性只能对应一个
                NSAssert(![existColumns containsObject:obj->_mapperColumn], @"字段%@对应多个属性", obj->_mapperColumn);
                [existColumns addObject:obj->_mapperColumn];
                
                if (!sqlAllColumns[obj->_mapperColumn]) {
                    // 判断表中缺少了哪些字段
                    JYSqlModelLog(@"缺少字段 %@", obj->_mapperColumn);
                    [addArray addObject:obj->_columnMode];
                } else {
                    // 判断表中字段的类别跟model中字段的类别是不是一样
                    _JYSqlColumnModel *sqlColMode = sqlAllColumns[obj->_mapperColumn];
                    if (sqlColMode->_columnType != obj->_columnMode->_columnType) {
                        needRemoval = true;
                        JYSqlModelLog(@"属性%@对应字段的类型改变，新类型：%@ 旧类型：%@", propertyName, JYGetColumnTypeDescription(obj->_columnMode->_columnType, propertyName), JYGetColumnTypeDescription(sqlColMode->_columnType, propertyName));
                    }
                }
            }];
            
            // 判断是否有字段是多余的，如果有的话则数据迁移
            if (!needRemoval) {
                [sqlAllColumns enumerateKeysAndObjectsUsingBlock:^(NSString *colName, _JYSqlColumnModel *colMode, BOOL * _Nonnull stop) {
                    if (![existColumns containsObject:colName]) {
                        needRemoval = true;
                        *stop = true;
                    }
                }];
            }
            
            // 先在旧表中添加字段。这样在数据迁移的时候不需要考虑在旧表中某些字段不存在的情况了
            if (addArray.count) {
                [dataBase inDeferredTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
                    [addArray enumerateObjectsUsingBlock:^(_JYSqlColumnModel *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        NSString *tmpSql = nil;
                        if (obj->_constraintType & JYColumnConstraintTypePrimaryKey) {
                            needRemoval = true;
                            tmpSql = [NSString stringWithFormat:@"alter table %@ add column %@ %@", tbName, obj->_name, JYGetColumnTypeDescription(obj->_columnType, obj->_name)];
                        } else {
                            tmpSql = [NSString stringWithFormat:@"alter table %@ add column %@ %@ %@", tbName, obj->_name, JYGetColumnTypeDescription(obj->_columnType, obj->_name), JYGetColumnConstraintDescription(obj)];
                        }
                        JYSqlModelLog(@"添加新字段 %@", tmpSql);
                        NSError *error;
                        [db executeUpdate:tmpSql withErrorAndBindings:&error];
                        if (error) {
                            JYSqlModelLog(@"添加失败：%@", error.localizedDescription);
                            if ([error.localizedDescription containsString:@"Cannot add a PRIMARY KEY"]) needRemoval = true;
                        }
                    }];
                }];
            }
            
            // 迁移数据
            if (needRemoval) {
                time_t now;
                time(&now);
                NSString *oldTbName = [NSString stringWithFormat:@"jy_%@_%ld", tbName, now];
                __block BOOL renameSuccess = false;
                
                [dataBase inDatabase:^(FMDatabase * _Nonnull db) {
                    NSString *tmpSql = [NSString stringWithFormat:@"alter table %@ rename to %@", tbName, oldTbName];
                    JYSqlModelLog(@"重命名旧表 %@", tmpSql);
                    renameSuccess = [db executeUpdate:tmpSql];
                }];
                
                if (renameSuccess) {
                    JY_CreateNewSql(tbName, meta->_mapper, dataBase);
                    
                    [dataBase inDeferredTransaction:^(FMDatabase * _Nonnull db, BOOL * _Nonnull rollback) {
                        NSMutableString *tmpSql = [NSMutableString stringWithFormat:@"insert into %@ (", tbName];
                        [existColumns enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                            [tmpSql appendFormat:@"%@,", obj];
                        }];
                        if (existColumns.count) {
                            [tmpSql replaceCharactersInRange:NSMakeRange(tmpSql.length-1, 1) withString:@")"];
                        } else {
                            [tmpSql appendString:@")"];
                        }
                        [tmpSql appendFormat:@" select %@ from %@", existColumns.count ? [existColumns componentsJoinedByString:@","]: @"*", oldTbName];
                        JYSqlModelLog(@"数据迁移，sql：%@", tmpSql);
                        [db executeUpdate:tmpSql];
                        
                        // 删除旧表，即使数据迁移失败也会删除掉有数据的旧表
                        tmpSql = [NSMutableString stringWithFormat:@"drop table if exists %@", oldTbName];
                        JYSqlModelLog(@"删除旧表 %@", tmpSql);
                        [db executeUpdate:tmpSql];
                    }];
                }
            }
        }
    }
}

+ (BOOL)addModel:(nonnull __kindof JYSqlModel *)model
{
    if (![model isKindOfClass:[JYSqlModel class]]) return false;
    if (self != [model class]) return false;
    
    FMDatabaseQueue *dataBase = JYGetDataBase([self dbFilePath]);
    NSMutableArray *colNames = @[].mutableCopy;
    NSMutableArray *colValues = @[].mutableCopy;
    _JYSqlModelMeta *meta = JYGetModeMeta(self);
    
    [meta->_mapper enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, _JYSqlModellPropertyMeta * _Nonnull obj, BOOL * _Nonnull stop) {
        if (!obj->_mapperColumn) return;
        [colNames addObject:obj->_mapperColumn];
        
        switch (obj->_columnMode->_columnType) {
            case JYColumnTypeUnknow:
                [colValues addObject:[NSNull null]];break;
            case JYColumnTypeInteger:
            case JYColumnTypeReal:
            case JYColumnTypeText:
            case JYColumnTypeBlob:
            case JYColumnTypeDate:
            case JYColumnTypeBool:
            {
                if (obj->_columnMode->_constraintType & JYColumnConstraintTypeAutoIncrement) {
                    [colValues addObject:[NSNull null]];
                    return;
                }
                id tempValue = nil;
                if (obj->_isCNumber) {
                    tempValue = JYGetValueFromCProperty(model, obj);
                } else {
                    tempValue = ((id (*)(id, SEL, id))(void *) objc_msgSend)((id)model, obj->_getter, (id)nil);
                }
                if (!tempValue) {
                    [colValues addObject:[NSNull null]];
                } else {
                    [colValues addObject:tempValue];
                }
            } break;
            default:break;
        }
    }];
    if (!colNames.count || colNames.count != colValues.count) {
        JYSqlModelLog(@"字段数量为0或与值的数量不相等");
        return false;
    }
    NSMutableArray *dots = @[].mutableCopy;
    for (NSInteger i = 0, count = colNames.count; i < count; i++) {
        [dots addObject:@"?"];
    }
    NSString *tbName = [[model class] tbName];
    NSString *sql = [NSString stringWithFormat:@"insert into %@ (%@) values(%@);", tbName, [colNames componentsJoinedByString:@","], [dots componentsJoinedByString:@","]];
    JYSqlModelLog(@"增sql：%@，values: %@", sql, [colValues componentsJoinedByString:@","]);
    __block BOOL result = false;
    
    [dataBase inDatabase:^(FMDatabase * _Nonnull db) {
        result = [db executeUpdate:sql withArgumentsInArray:colValues];
    }];
    JYSqlModelLog(@"数据插入%@", result ? @"成功" : @"失败");
    return result;
}

+ (BOOL)addModels:(nonnull NSArray<__kindof JYSqlModel *> *)models
{
    if (!models || !models.count) return false;
    
    __block BOOL result = true;
    [models enumerateObjectsUsingBlock:^(__kindof JYSqlModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        BOOL tempResult = [self addModel:obj];
        if (!tempResult) {
            JYSqlModelLog(@"第%tu条数据插入失败", idx);
            result = false;
        }
    }];
    return result;
}

- (BOOL)addToSql
{
    if (!self) return false;
    return [[self class] addModel:self];
}

+ (BOOL)deleteModelBySql:(nonnull NSString *)sql
{
    if (!sql || ![sql length]) return false;
    
    FMDatabaseQueue *dataBase = JYGetDataBase([self dbFilePath]);
    __block BOOL result = false;
    [dataBase inDatabase:^(FMDatabase * _Nonnull db) {
        result = [db executeUpdate:sql];
    }];
    JYSqlModelLog(@"删sql：%@, %@", sql, result ? @"成功" : @"失败");
    return result;
}

+ (BOOL)deleteModelByPrimaryKey:(NSString *)primaryKey value:(NSInteger)value
{
    NSString *realKey = JYGetPrimaryKey(self);
    if (![primaryKey isEqualToString:realKey]) return false;
    
    NSString *tbName = [self tbName];
    NSString *sql = [NSString stringWithFormat:@"delete from %@ where %@ = %zd", tbName, realKey, value];
    FMDatabaseQueue *dataBase = JYGetDataBase([self dbFilePath]);
    __block BOOL result = false;
    [dataBase inDatabase:^(FMDatabase * _Nonnull db) {
        result = [db executeUpdate:sql];
    }];
    JYSqlModelLog(@"删sql：%@, %@", sql, result ? @"成功" : @"失败");
    return result;
}

- (BOOL)deleteFromSql
{
    __block NSString *pk = nil;
    __block id tempValue = nil;
    _JYSqlModelMeta *meta = JYGetModeMeta([self class]);
    [meta->_mapper enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, _JYSqlModellPropertyMeta * _Nonnull obj, BOOL * _Nonnull stop) {
        if (obj->_columnMode->_constraintType & JYColumnConstraintTypePrimaryKey) {
            pk = obj->_mapperColumn;
            if (obj->_isCNumber) {
                tempValue = JYGetValueFromCProperty(self, obj);
            } else {
                tempValue = ((id (*)(id, SEL, id))(void *) objc_msgSend)((id)self, obj->_getter, (id)nil);
            }
            *stop = true;
        }
    }];
    if (!pk  || !tempValue) return false;
    
    NSString *tbName = [[self class] tbName];
    NSString *sql = [NSString stringWithFormat:@"delete from %@ where %@ = %@", tbName, pk, tempValue];
    FMDatabaseQueue *dataBase = JYGetDataBase([[self class] dbFilePath]);
    __block BOOL result = false;
    [dataBase inDatabase:^(FMDatabase * _Nonnull db) {
        result = [db executeUpdate:sql];
    }];
    JYSqlModelLog(@"删sql：%@, %@", sql, result ? @"成功" : @"失败");
    return result;
}

+ (BOOL)updateModel:(nonnull __kindof JYSqlModel *)model primaryKey:(NSString *)primaryKey value:(NSInteger)value
{
    if (self != [model class]) return false;
    NSString *realKey = JYGetPrimaryKey(self);
    if (![primaryKey isEqualToString:realKey]) return false;
    
    NSString *tbName = [[model class] tbName];
    NSMutableString *sql = [NSMutableString stringWithFormat:@"update %@ set ", tbName];
    NSMutableArray *values = @[].mutableCopy;
    _JYSqlModelMeta *meta = JYGetModeMeta(self);
    [meta->_mapper enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, _JYSqlModellPropertyMeta * _Nonnull obj, BOOL * _Nonnull stop) {
        if (!obj->_mapperColumn) return;
        JYColumnConstraintType constraintType = obj ->_columnMode->_constraintType;
        // 字段约束是AutoIncrement或者PrimaryKey的话就不赋值了
        if (constraintType & JYColumnConstraintTypeAutoIncrement || constraintType & JYColumnConstraintTypePrimaryKey) return;
        
        [sql appendFormat:@"%@ = ", obj->_mapperColumn];
        
        switch (obj->_columnMode->_columnType) {
            case JYColumnTypeUnknow:
                [sql appendString:@"null,"];break;
            case JYColumnTypeInteger:
            case JYColumnTypeReal:
            case JYColumnTypeText:
            case JYColumnTypeBlob:
            case JYColumnTypeDate:
            case JYColumnTypeBool:
            {
                [sql appendString:@"? ,"];
                
                id tempValue = nil;
                if (obj->_isCNumber) {
                    tempValue = JYGetValueFromCProperty(model, obj);
                } else {
                    tempValue = ((id (*)(id, SEL, id))(void *) objc_msgSend)((id)model, obj->_getter, (id)nil);
                }
                if (!tempValue) {
                    [values addObject:[NSNull null]];
                } else {
                    [values addObject:tempValue];
                }
            }break;
            default:break;
        }
    }];
    [sql replaceCharactersInRange:NSMakeRange(sql.length-1, 1) withString:@""];
    [sql appendFormat:@"where %@ = %zd;", primaryKey, value];
    
    FMDatabaseQueue *dataBase = JYGetDataBase([self dbFilePath]);
    __block BOOL result = false;
    [dataBase inDatabase:^(FMDatabase * _Nonnull db) {
        result = [db executeUpdate:sql withArgumentsInArray:values];
    }];
    JYSqlModelLog(@"改sql：%@, values:%@, %@", sql, [values componentsJoinedByString:@","], result ? @"成功" : @"失败");
    return result;
}

+ (BOOL)updateModelBySql:(NSString *)sql
{
    if (!sql || ![sql length]) return false;
    
    FMDatabaseQueue *dataBase = JYGetDataBase([self dbFilePath]);
    __block BOOL result = false;
    [dataBase inDatabase:^(FMDatabase * _Nonnull db) {
        result = [db executeUpdate:sql];
    }];
    JYSqlModelLog(@"改sql：%@, %@", sql, result ? @"成功" : @"失败");
    return result;
}

+ (nullable NSArray<__kindof JYSqlModel *> *)findModelsBySql:(nonnull NSString *)sql
{
    if (!sql || !sql.length) return nil;
    
    NSMutableArray *models = @[].mutableCopy;
    FMDatabaseQueue *dataBase = JYGetDataBase([self dbFilePath]);
    [dataBase inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:sql];
        while ([resultSet next]) {
            id model = JYGetModelFromSql(resultSet, self);
            [models addObject:model];
        }
    }];
    JYSqlModelLog(@"查sql：%@", sql);
    return [models copy];
}

+ (nullable NSArray<__kindof JYSqlModel *> *)findAllModels
{
    NSMutableArray *models = @[].mutableCopy;
    FMDatabaseQueue *dataBase = JYGetDataBase([self dbFilePath]);
    NSString *sql = [NSString stringWithFormat:@"select * from %@", [self tbName]];
    [dataBase inDatabase:^(FMDatabase * _Nonnull db) {
        FMResultSet *resultSet = [db executeQuery:sql];
        while ([resultSet next]) {
            id model = JYGetModelFromSql(resultSet, self);
            [models addObject:model];
        }
    }];
    JYSqlModelLog(@"查sql：%@", sql);
    return [models copy];
}

static inline __attribute__((always_inline))
id JYGetValueFromCProperty (__unsafe_unretained id model,
                            __unsafe_unretained _JYSqlModellPropertyMeta *meta) {
    id result = nil;
    switch (meta->_type & JYEncodingTypeMask) {
        case JYEncodingTypeBool:
            result = @(((BOOL (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_getter, (id)nil));
            break;
        case JYEncodingTypeInt8:
            result = @(((int8_t (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_getter, (id)nil));
            break;
        case JYEncodingTypeUInt8:
            result = [NSNumber numberWithUnsignedChar:((uint8_t (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_getter, (id)nil)];
            break;
        case JYEncodingTypeInt16:
            result = [NSNumber numberWithShort:((int16_t (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_getter, (id)nil)];
            break;
        case JYEncodingTypeUInt16:
            result = [NSNumber numberWithUnsignedShort:((uint16_t (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_getter, (id)nil)];
            break;
        case JYEncodingTypeInt32:
            result = [NSNumber numberWithInt:((int32_t (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_getter, (id)nil)];
            break;
        case JYEncodingTypeUInt32:
            result = [NSNumber numberWithUnsignedInt:((uint32_t (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_getter, (id)nil)];
            break;
        case JYEncodingTypeInt64:
            result = [NSNumber numberWithLongLong:((int64_t (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_getter, (id)nil)];
            break;
        case JYEncodingTypeUInt64:
            result = [NSNumber numberWithUnsignedLongLong:((uint64_t (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_getter, (id)nil)];
            break;
        case JYEncodingTypeFloat:
            result = [NSNumber numberWithFloat:(((float (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_getter, (id)nil))];
            break;
        case JYEncodingTypeDouble:
            result = [NSNumber numberWithDouble:(((double (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_getter, (id)nil))];
            break;
        case JYEncodingTypeLongDouble:
            result = [NSNumber numberWithDouble:(((long double (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_getter, (id)nil))];
            break;
        default:break;
    }
    return result;
}

static inline __attribute__((always_inline))
void ModelSetNumberToProperty(__unsafe_unretained id model,
                              __unsafe_unretained NSNumber *num,
                              __unsafe_unretained _JYSqlModellPropertyMeta *meta) {
    if (!num || [num isKindOfClass:[NSNull class]]) return;
    
    switch (meta->_type & JYEncodingTypeMask) {
        case JYEncodingTypeBool: {
            ((void (*)(id, SEL, bool))(void *) objc_msgSend)((id)model, meta->_setter, num.boolValue);
        } break;
        case JYEncodingTypeInt8: {
            ((void (*)(id, SEL, int8_t))(void *) objc_msgSend)((id)model, meta->_setter, (int8_t)num.charValue);
        } break;
        case JYEncodingTypeUInt8: {
            ((void (*)(id, SEL, uint8_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint8_t)num.unsignedCharValue);
        } break;
        case JYEncodingTypeInt16: {
            ((void (*)(id, SEL, int16_t))(void *) objc_msgSend)((id)model, meta->_setter, (int16_t)num.shortValue);
        } break;
        case JYEncodingTypeUInt16: {
            ((void (*)(id, SEL, uint16_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint16_t)num.unsignedShortValue);
        } break;
        case JYEncodingTypeInt32: {
            ((void (*)(id, SEL, int32_t))(void *) objc_msgSend)((id)model, meta->_setter, (int32_t)num.intValue);
        }
        case JYEncodingTypeUInt32: {
            ((void (*)(id, SEL, uint32_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint32_t)num.unsignedIntValue);
        } break;
        case JYEncodingTypeInt64: {
            if ([num isKindOfClass:[NSDecimalNumber class]]) {
                ((void (*)(id, SEL, int64_t))(void *) objc_msgSend)((id)model, meta->_setter, (int64_t)num.stringValue.longLongValue);
            } else {
                ((void (*)(id, SEL, uint64_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint64_t)num.longLongValue);
            }
        } break;
        case JYEncodingTypeUInt64: {
            if ([num isKindOfClass:[NSDecimalNumber class]]) {
                ((void (*)(id, SEL, int64_t))(void *) objc_msgSend)((id)model, meta->_setter, (int64_t)num.stringValue.longLongValue);
            } else {
                ((void (*)(id, SEL, uint64_t))(void *) objc_msgSend)((id)model, meta->_setter, (uint64_t)num.unsignedLongLongValue);
            }
        } break;
        case JYEncodingTypeFloat: {
            float f = num.floatValue;
            if (isnan(f) || isinf(f)) f = 0;
            ((void (*)(id, SEL, float))(void *) objc_msgSend)((id)model, meta->_setter, f);
        } break;
        case JYEncodingTypeDouble: {
            double d = num.doubleValue;
            if (isnan(d) || isinf(d)) d = 0;
            ((void (*)(id, SEL, double))(void *) objc_msgSend)((id)model, meta->_setter, d);
        } break;
        case JYEncodingTypeLongDouble: {
            long double d = num.doubleValue;
            if (isnan(d) || isinf(d)) d = 0;
            ((void (*)(id, SEL, long double))(void *) objc_msgSend)((id)model, meta->_setter, (long double)d);
        } break;
        case JYEncodingTypeObject: {
            switch (meta->_nsType) {
                case JYEncodingTypeNSNumber:
                case JYEncodingTypeNSDecimalNumber:
                {
                    ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, meta->_setter, num);
                } break;
                default:
                    break;
            }
        } break;
        default: break;
    }
}

static JYSqlModel * JYGetModelFromSql(FMResultSet *result, Class cls) {
    if (!result || !cls) return nil;
    
    id model = [cls new];
    _JYSqlModelMeta *meta = JYGetModeMeta(cls);
    
    [meta->_mapper enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, _JYSqlModellPropertyMeta * _Nonnull obj, BOOL * _Nonnull stop) {
        if (!obj->_mapperColumn) return;
        
        switch (obj->_columnMode->_columnType) {
            case JYColumnTypeInteger: {
                NSNumber *objcValue = [result objectForColumn:obj->_mapperColumn];
                ModelSetNumberToProperty(model, objcValue, obj);
                // 避免objcValue释放，程序崩溃
                if (objcValue) [objcValue class];
            }break;
                
            case JYColumnTypeReal: {
                NSNumber *objcValue = [result objectForColumn:obj->_mapperColumn];
                ModelSetNumberToProperty(model, objcValue, obj);
                if (objcValue) [objcValue class];
            }break;
                
            case JYColumnTypeText: {
                NSString *value = [result stringForColumn:obj->_mapperColumn];
                switch (obj->_nsType) {
                    case JYEncodingTypeNSString:
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, obj->_setter, value);break;
                    case JYEncodingTypeNSMutableString:
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, obj->_setter, ((NSString *)value).mutableCopy);break;
                    case JYEncodingTypeNSURL: {
                        NSCharacterSet *set = [NSCharacterSet whitespaceAndNewlineCharacterSet];
                        NSString *str = [value stringByTrimmingCharactersInSet:set];
                        if (str.length == 0) {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, obj->_setter, nil);
                        } else {
                            ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, obj->_setter, [[NSURL alloc] initWithString:str]);
                        }
                    }break;
                    default:
                        break;
                }
            }break;
                
            case JYColumnTypeBlob: {
                NSData *value = [result dataForColumn:obj->_mapperColumn];
                switch (obj->_nsType) {
                    case JYEncodingTypeNSData:
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, obj->_setter, value);break;
                    case JYEncodingTypeNSMutableData:
                        ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, obj->_setter, ((NSData *)value).mutableCopy);break;
                    default:
                        break;
                }
            }break;
                
            case JYColumnTypeDate: {
                NSDate *value = [result dateForColumn:obj->_mapperColumn];
                ((void (*)(id, SEL, id))(void *) objc_msgSend)((id)model, obj->_setter, value);
            }break;
                
            case JYColumnTypeBool: {
                BOOL cValue = [result boolForColumn:obj->_mapperColumn];
                NSNumber *objcValue = [NSNumber numberWithBool:cValue];
                ModelSetNumberToProperty(model, objcValue, obj);
                // 避免objcValue释放，程序崩溃
                if (objcValue) [objcValue class];
            }break;
                
            default:
                break;
        }
    }];
    return model;
}
@end
