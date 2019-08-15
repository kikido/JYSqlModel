
![](https://img.shields.io/badge/license-MIT-green.svg)
![](https://img.shields.io/badge/version-1.0.0-blue)
![](https://img.shields.io/badge/codecov-95%25-red)

`JYSqlModel`是一个高效的 model、sqlite数据的转换工具。在 JYSqlModel，每一条数据库的数据都会被当做一个 model，所以当你对 model 执行相应的增删改查操作时，即对数据库进行着增删改查操作，这意味着你不再需要记得什么字段，什么约束，甚至可以不再使用 sql 语句来操作数据库！
JYSqlModel 依赖于库[FMDB](https://github.com/ccgus/fmdb)，使用前请保证你的项目中有这个库。
JYSqlModel 的思路来源来自于[YYModel](https://github.com/ibireme/YYModel)

使用前请将`JYSqlModel`和`JYClassInfo`的 .h 和 .m 文件，放到工程中。

### 创建表

在 JYSqlModel 中，一个 model 对应于一个表。首先，你需要给这个表确定好一个名字，所以你必须在 model 内重载 JYSqlModel 的类方法`+ (nonnull NSString *)tbName;`。注意这个名字不能重复重复。
系统会在启动的时候，会根据 model 结构创建相应的表。表中字段(column)与 model 属性是一一对应的，在默认情况下，字段名字即是属性名字，当然你也可以使用协议中的方法自定义字段名，这个后面会详细讲。字段的类型会根据属性的类型分成不同的类型，目前只支持下表中的几种类型：



| 字段类型 | 描述 | 对应属性类型 |
| --- | --- | --- |
| integer | 整型数 | c的整型，NSNumber |
| real | 浮点数 | c的浮点型，NSDecimalNumber  |
| text | 文本 | NSString，NSMutableString，NSURL |
| blob | 二进制数据 | NSData，NSMutableData |
| date | 日期 | NSDate |
| bool | 布尔值 | c的bool |
| unknow | 除上面所以，会报错 | 除上面所有 |

如果你的类型不是上面支持的几种类型之一，那么就会被归为 unkonw 类型，随即就会报错。这样做的原因一方面是因为自己的知识不够丰富，不知道怎么处理其它的类型，另一方面避免复杂类型引起不可预料的错误。在后期的话可能还会支持 NSArray 等容器类型。


下面是一个简单的例子：
```
@interface Student : JYSqlModel
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *school;
@property (nonatomic, assign) NSInteger age;
@property (nonatomic, assign) CGFloat height;
@property (nonatomic, strong) NSDate *birthDay;
@end

@implementation Student
+ (NSString *)tbName
{
    return @"sudent";
}
@end
```

下面是创建相应表的 sql：
```
create table if not exists sudent (school text ,age integer ,birthDay date ,name text ,height real)
```

是不是很简单，你只需要新建一个`JYSqlModel`的子类，并给它指定一个表名，就能自动的创建一个表。

### 增

JYSqlModel 提供了以下几种方法来帮助你将 model 写入数据库：
```
// 1
+ (BOOL)addModel:(nonnull __kindof JYSqlMode *)model;
// 2
+ (BOOL)addModels:(nonnull NSArray<__kindof JYSqlMode *> *)models;
// 3
- (BOOL)addToSql;
```

方法1和方法2类似，都是使用类方法来添加 model 到数据库中。需要注意的是，model 的类需要跟类一致，否则会添加失败。
方法3是实例方法。添加成功会返回 YES，否则返回 NO

### 删

JYSqlModel 提供了以下几种方法来帮助你将 model 从数据库中删除：

```
// 1
+ (BOOL)deleteModelBySql:(nonnull NSString *)sql;
// 2
+ (BOOL)deleteModelByPrimaryKey:(NSString *)primaryKey value:(NSInteger)value;
// 3
+ - (BOOL)deleteFromSql;
```

方法1的话需要你自己写删除 sql，适用于删除语句比较简单或者批量删除的时候。你可以在子类中，根据这个方法封装一个更简单的方法。举个例子：
```
@interface Student : JYSqlMode    
+ (BOOL)deleteModeByPKValue:(NSInteger)value;
@end

@implementation JYPerson
 + (BOOL)deleteModeByPKValue:(NSInteger)value {
    NSString *sql = [NSString stringWithFormat:@"delete from tbName where pk = %zd", value];
    [JYSonModel deleteModelBySql:sql];
 }
 @end
```
现在你只需要一个pk值就能删除数据库记录了。当然你也可以封装一个实例方法，这样连参数都不需要了。

方法2需要你指定一个主键名字以及主键值来删除相应记录。类似于方法1，你也可以根据该方法封装一个更简便的方法！

方法3不需要你提供什么参数，使用起来更简单，但是如果对应表中没有主键，该删除方法就会失败，因为无法定位到具体到某一条记录。

### 改

JYSqlModel 提供了以下几种方法来帮助你更新数据库中的记录：
```
// 1
+ (BOOL)updateModelBySql:(NSString *)sql;
// 2
+ (BOOL)updateModel:(nonnull __kindof JYSqlMode *)model primaryKey:(NSString *)primaryKey value:(NSInteger)value;
```

方法1的话需要你自己提供更新 sql，适用于更新字段比较少或者批量更新的时候。

方法2需要你提供一个主键来确定是哪条记录，以便更新相应数据。该方法将更新除主键和autoincrement以外所有的字段，适用于更新字段比较多的情况。

### 查

JYSqlModel 提供了以下几种方法来帮助你查找数据库中的记录：
```
// 1
+ (nullable NSArray<__kindof JYSqlMode *> *)findModelsBySql:(nonnull NSString *)sql;
// 2
+ (nullable NSArray<__kindof JYSqlMode *> *)findAllModels;
```

方法1需要你自己提供查找 sql，返回结果将以 model 数组返回。

方法2将会查找出表中所有的记录，以 model 数组的形式返回。


### 数据迁移

在项目更新中，如果我们需要增加、删除 model 中的某些属性，或者改变属性的类型要怎么办呢？
很简单，你只需要对 model 进行修改，在项目运行时，JYSqlMode 会检测新 model 的结构以及旧表的结构，来判断是否需要进行数据迁移。
所谓的`数据迁移`也就是，将旧表重命名，根据新 model 的结构新建一个表，然后将旧表的数据迁移到新的表中。如此操作之后，新表的结构与新 model 的结构就一一对应了，保证了你在执行增删改查操作时不会出错。

当然，也有一些情况下，可能你做了修改也不会触发数据迁移。例如，如果仅仅是改变了字段的约束条件，那么是不会触发数据迁移的。解决办法最后面会给出。

### JYSqlMode

下面是协议`JYSqlMode`的可选方法，帮助你执行一些自定义操作：
```
// 1
+ (nullable NSDictionary<NSString *, id> *)jyCustomPropertyMapper;
// 2
+ (nullable NSDictionary<NSString *, NSDictionary *> *)jyCustomPropertyConstraint;
```


方法1帮助你实现自定义 属性 -> 表字段名 的映射。举个例子：
```
@interface Student : JYSqlMode <JYSqlMode>
@property NSString *name;
@property NSString *title;
@property NSInteger age;
@end

implementation Student
+ (nullable NSDictionary<NSString *, id> *)jyCustomPropertyMapper {
return @{
	      @"name"   : @"fName",
	      @"title"  : @"ftitle",
	      @"age"    : @"fage"
	     }
}
@end
```

在相应的表中，fName 将会对应属性 name，ftitle 将会对应属性 title，fage 将会对应属性 age


方法2帮助你实现自定义字段的约束条件。目前仅支持以下几种约束类型：

- JYColumnConstraintKeyNotNull -> not null
- JYColumnConstraintKeyDefault -> default
- JYColumnConstraintKeyDefaultValue -> 默认值，需要与 JYColumnConstraintKeyDefault 配套使用
- JYColumnConstraintKeyUnique -> unique
- JYColumnConstraintKeyPrimaryKey -> primary key
- JYColumnConstraintKeyAutoIncrement -> autoincrement

需要注意的是，JYColumnConstraintKeyDefault 需要配合 JYColumnConstraintKeyDefaultValue 使用，设置一个默认值。
举个例子：

```
@interface Student : JYSqlModel <JYSqlModel>
@property (nonatomic, assign) NSInteger fid;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *school;
@property (nonatomic, assign) CGFloat height;
@property (nonatomic, strong) NSDate *birthDay;
@end

@implementation Student
+ (nullable NSDictionary<NSString *, NSDictionary *> *)jyCustomPropertyConstraint;
{
    return @{
             @"fid" : @{
                     JYColumnConstraintKeyPrimaryKey : @YES,
                     JYColumnConstraintKeyUnique : @YES
                     JYColumnConstraintKeyAutoIncrement : @YES
                     },
             @"school" : @{
                     JYColumnConstraintKeyDefault : @YES,
                     JYColumnConstraintKeyDefaultValue : @"背背山小学"
                     }
             };
}
@end
```

这样子，你就定义了一个`primary key unique autoincrement`的主键 fid，以及一个`default '背背山小学'`的字段 school。


### @note

限于个人水平，JYSqlModel 肯定会在一些的问题。也许你会奇怪明明按说明操作了，但没有出现想要的结构。下面我将总结一下使用时需要注意的地方：

1. 已存在一个旧表，若只是修改了相应字段的约束条件，这些约束条件是不会立刻生效的。一个解决办法是预留一个字段，当你需要更新表结构的时候修改这个预留字段的名字
2. 已存在一个旧表，如果你为它设置了一个主键，抱歉设置会失败。解决方法参考第1条
3. NSNumber类型的属性会存储到 integer 类型的字段中，如果想保存成浮点数的话，请将属性类型改为 NSDecimalNumber 或者直接使用 C 的浮点类型 float, double等
4. 如果你在运行时动态的为 model 新增了属性，抱歉，表结构也不会更新



