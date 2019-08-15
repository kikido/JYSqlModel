//
//  JYSqlModel.h
//  190611
//
//  Created by dqh on 2019/8/5.
//  Copyright © 2019 duqianhang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString * const JYColumnConstraintKey;
extern JYColumnConstraintKey JYColumnConstraintKeyNotNull;
extern JYColumnConstraintKey JYColumnConstraintKeyDefault;
extern JYColumnConstraintKey JYColumnConstraintKeyDefaultValue;
extern JYColumnConstraintKey JYColumnConstraintKeyUnique;
extern JYColumnConstraintKey JYColumnConstraintKeyPrimaryKey;
extern JYColumnConstraintKey JYColumnConstraintKeyAutoIncrement;

@interface JYSqlModel : NSObject

/**
 为 model 对应的表设置一个名字

 @note 该名字不能重复。子类必须重载
 
 @return 表的名字
 */
+ (nonnull NSString *)tbName;

/**
 给定数据库文件db地址，默认地址为 documents/JyDb.sqlite
 
 @discussion 你可以修改该方法的返回值来修改db的文件地址
 
 @note 子类不能重载该方法
 
 @return db文件地址
 */
+ (nonnull NSString *)dbFilePath;

/**
 是否输出调试信息。默认为NO
 
 @note 子类不能重载该方法
 
 @return 是否显示调试信息
 */
+ (BOOL)debugLogEnabled;

#pragma mark - 增删改查

/**
 添加一个model到数据库表中
 
 @discussion 需要注意，类跟model的类需要保持一致，否则添加会失败。
 举个错误的例子：
 [JYSonMode addModel:(JYSqlModel *)model];
 请避免上述的写法，而是像下面这样子使用
 [JYSonMode addModel:(JYSonMode *)model];
 
 @param model 数据模型，不能为空
 @return 保存数据是否成功
 */
+ (BOOL)addModel:(nonnull __kindof JYSqlModel *)model;

/**
 添加一些model到数据库表中
 
 @discussion 需要注意的事情参考上面的那个方法 ⬆️
 
 @param models 数据模型，不能为空
 @return 保存数据是否是否成功，如果保存一个失败则返回失败
 */
+ (BOOL)addModels:(nonnull NSArray<__kindof JYSqlModel *> *)models;

/**
 实例方法。将这个model添加到数据库表中
 
 @return 保存数据是否成功
 */
- (BOOL)addToSql;


/**
 根据sql在数据库中执行删除操作
 
 @discussion 如果删除语句比较简单的话（比如根据pk键），或者批量删除，可以根据这个方法，
 然后封装一个比较简单的方法来执行删除操作。
 
 举个例子：
 @interface JYSonModel : JYSqlModel
 + (BOOL)deleteModeByPKValue:(NSInteger)value;
 
 @implementation JYPerson
 + (BOOL)deleteModeByPKValue:(NSInteger)value {
 NSString *sql = [NSString stringWithFormat:@"delete from tbName where pk = %zd", value];
 [JYSonModel deleteModelBySql:sql];
 }
 像上面这么使用就会简单许多
 
 @param sql 删除sql
 @return 执行sql是否成功
 */
+ (BOOL)deleteModelBySql:(nonnull NSString *)sql;

/**
 根据pk键在数据库中删除数据
 
 @param primaryKey 数据库中pk键的名字
 @param value pk键的值
 @return 删除是否成功
 */
+ (BOOL)deleteModelByPrimaryKey:(NSString *)primaryKey value:(NSInteger)value;


/**
 从数据库中删除该model的数据
 
 @note 该方法只适应于有主键的表，如果没有主键的话无法确定是哪条数据
 
 @return 删除是否成功
 */
- (BOOL)deleteFromSql;

/**
 根据pk键更新一个model的数据
 
 @discussion 该方法适用于更新字段比较多的时候。
 
 @note 需要注意，类跟model的类需要保持一致，否则会失败。
 如果使用该方法，需要表中存在一个主键。model的主键值不能有过修改过，否则可能会修改掉别的记录
 
 param primaryKey 表中主键的名称
 param value 主键的值
 @param model model实例
 @return 更新数据是否成功
 */

+ (BOOL)updateModel:(nonnull __kindof JYSqlModel *)model primaryKey:(NSString *)primaryKey value:(NSInteger)value;

/**
 根据sql更新数据
 
 @param sql 更新sql
 @return 执行sql是否成功
 */
+ (BOOL)updateModelBySql:(NSString *)sql;


/**
 根据sql查找数据
 
 @discussion 需要注意，类跟model的类需要保持一致，否则会失败。
 
 @param sql 查找sql
 @return 查找结果，自动转换成model数组返回
 */
+ (nullable NSArray<__kindof JYSqlModel *> *)findModelsBySql:(nonnull NSString *)sql;


/**
 查找所有表中的数据
 
 @return 查找结果，自动转换成model数组返回
 */
+ (nullable NSArray<__kindof JYSqlModel *> *)findAllModels;
@end



@protocol JYSqlModel <NSObject>
@optional

/**
 自定义属性与字段之间的映射
 
 举个例子：
 
 sqlite:
 columnName    columnType
 fname         text
 ftitle        text
 fage          integer
 
 
 model:
 @i nterface JYPerson : JYSqlModel
 @property NSString *name;
 @property NSString *title;
 @property NSInteger age;
 @end
 
 implementation JYPerson
 + (nullable NSDictionary<NSString *, id> *)jyCustomPropertyMapper {
 return @{
 @"name"   : @"fName",
 @"title"  : @"ftitle",
 @"age"    : @"fage"
 }
 }
 
 */
+ (nullable NSDictionary<NSString *, id> *)jyCustomPropertyMapper;

/**
 自定义属性的约束条件
 1. notNull
 2. default
 3. defaultValue
 4. unique
 5. primaryKey
 */


/**
 自定义属性对应的字段的约束。
 
 @return 返回一个字典。其中key为属性名，value为约束字典。
 
 举个例子：
 
 + (nullable NSDictionary<NSString *, NSDictionary *> *)jyCustomPropertyConstraint {
 return @{@"name"  : @{
 JYColumnConstraintKeyDefault : @YES,
 JYColumnConstraintKeyDefaultValue : @"测试"
 },
 @"id"  : @{
 JYColumnConstraintKeyUnique : @YES,
 JYColumnConstraintKeyPrimaryKey : @YES
 }
 }
 }
 
 通过上面的返回值，你设置了name对应的字段有默认值，默认值为"测试"；设置了id对应的字段唯一且为主键。更多约束可以查看 JYColumnConstraintKey
 
 有点纠结key是属性名好还是字段名比较合适，最终还是选择了属性名。因为在写代码的时候，直接操作属性比较直观；属性名肯定是唯一的；属性有一个对应的字段名
 
 */
+ (nullable NSDictionary<NSString *, NSDictionary *> *)jyCustomPropertyConstraint;
@end

NS_ASSUME_NONNULL_END
