//
//  DIYCPMgr.h
//  ChangePrices
//
//  Created by viktorhuang on 2026/3/16.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 错误码：商品尚未配置价格（App Store Connect 上没有 price schedule）
extern NSInteger const DIYCPMgrErrorCodeNoPriceSchedule;

#pragma mark - Models

@interface DIYCPApp : NSObject

@property (nonatomic, copy) NSString *appId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *bundleId;
@property (nonatomic, copy) NSString *sku;
@property (nonatomic, copy, nullable) NSString *iconURL;

@end

/// IAP 商品模型（CONSUMABLE / NON_CONSUMABLE / NON_RENEWING_SUBSCRIPTION）
@interface DIYCPInAppPurchase : NSObject

@property (nonatomic, copy) NSString *iapId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *productId;
@property (nonatomic, copy) NSString *inAppPurchaseType; // CONSUMABLE, NON_CONSUMABLE, NON_RENEWING_SUBSCRIPTION
@property (nonatomic, copy) NSString *state;             // APPROVED, READY_TO_SUBMIT, etc.

@end

/// 自动续期订阅模型
@interface DIYCPSubscription : NSObject

@property (nonatomic, copy) NSString *subscriptionId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *productId;
@property (nonatomic, copy) NSString *state;
@property (nonatomic, copy) NSString *subscriptionPeriod; // ONE_WEEK, ONE_MONTH, TWO_MONTHS, THREE_MONTHS, SIX_MONTHS, ONE_YEAR

@end

/// 订阅分组模型
@interface DIYCPSubscriptionGroup : NSObject

@property (nonatomic, copy) NSString *groupId;
@property (nonatomic, copy) NSString *referenceName;
@property (nonatomic, strong) NSArray<DIYCPSubscription *> *subscriptions;

@end

/// 地区/国家模型
@interface DIYCPTerritory : NSObject

@property (nonatomic, copy) NSString *territoryId; // e.g. "USA", "CHN"
@property (nonatomic, copy) NSString *currency;    // e.g. "USD", "CNY"

@end

/// 价格点模型（某个商品在某个地区的价格）
@interface DIYCPPricePoint : NSObject

@property (nonatomic, copy) NSString *pricePointId;
@property (nonatomic, copy) NSString *customerPrice; // 用户看到的价格
@property (nonatomic, copy) NSString *proceeds;      // 开发者收入
@property (nonatomic, strong) DIYCPTerritory *territory;

@end

/// 商品当前价格信息（包含 territory 和 price）
@interface DIYCPCurrentPrice : NSObject

@property (nonatomic, copy) NSString *startDate;
@property (nonatomic, strong) DIYCPPricePoint *manual; // 手动设置的价格

@end

#pragma mark - Manager

@interface DIYCPMgr : NSObject

+ (instancetype)shared;

/// 清除缓存的 JWT Token（凭据变更时调用）
- (void)invalidateToken;

/// 获取账号下所有 App 列表
- (void)fetchAllAppsWithCompletion:(void (^)(NSArray<DIYCPApp *> * _Nullable apps, NSError * _Nullable error))completion;

/// 获取某个 App 的 IAP 商品列表
- (void)fetchInAppPurchasesForAppId:(NSString *)appId
                         completion:(void (^)(NSArray<DIYCPInAppPurchase *> * _Nullable iaps, NSError * _Nullable error))completion;

/// 获取某个 App 的订阅分组列表（每个分组包含其下的订阅）
- (void)fetchSubscriptionGroupsForAppId:(NSString *)appId
                             completion:(void (^)(NSArray<DIYCPSubscriptionGroup *> * _Nullable groups, NSError * _Nullable error))completion;

/// 获取 IAP 商品在指定地区的价格点
/// @param territories 要查询的地区代码数组（最多10个，如 @[@"USA", @"CHN", @"JPN"]），传 nil 或空数组则查询所有地区
- (void)fetchIAPPricePointsForIAPId:(NSString *)iapId
                         territories:(NSArray<NSString *> * _Nullable)territories
                          completion:(void (^)(NSArray<DIYCPPricePoint *> * _Nullable pricePoints, NSError * _Nullable error))completion;

/// 获取 IAP 价格点的等价价格（equalizations）
/// 给定一个基准价格点 ID，返回该价格在所有其他国家/地区的等价价格（每个地区一个）
/// GET /v1/inAppPurchasePricePoints/{id}/equalizations?include=territory
/// @param pricePointId 基准价格点的 ID（如 USA 的某个 pricePointId）
/// @param completion 完成回调，返回所有地区的等价价格点数组
- (void)fetchIAPEqualizationsForPricePointId:(NSString *)pricePointId
                                  completion:(void (^)(NSArray<DIYCPPricePoint *> * _Nullable pricePoints, NSError * _Nullable error))completion;

/// 获取 IAP 商品当前各地区定价
- (void)fetchIAPCurrentPricesForIAPId:(NSString *)iapId
                           completion:(void (^)(NSArray<DIYCPPricePoint *> * _Nullable prices, NSError * _Nullable error))completion;

/// 获取订阅商品在所有地区的价格点
- (void)fetchSubscriptionPricePointsForSubId:(NSString *)subscriptionId
                                   territory:(NSString * _Nullable)filterTerritory
                                  completion:(void (^)(NSArray<DIYCPPricePoint *> * _Nullable pricePoints, NSError * _Nullable error))completion;

/// 获取订阅价格点的等价价格（equalizations）
/// 给定一个基准价格点 ID，返回该价格在所有其他国家/地区的等价价格（每个地区一个）
/// GET /v1/subscriptionPricePoints/{id}/equalizations?include=territory
/// @param pricePointId 基准价格点的 ID（如 USA 的某个 pricePointId）
/// @param completion 完成回调，返回所有地区的等价价格点数组
- (void)fetchSubscriptionEqualizationsForPricePointId:(NSString *)pricePointId
                                           completion:(void (^)(NSArray<DIYCPPricePoint *> * _Nullable pricePoints, NSError * _Nullable error))completion;

/// 获取订阅商品当前各地区定价
- (void)fetchSubscriptionCurrentPricesForSubId:(NSString *)subscriptionId
                                    completion:(void (^)(NSArray<DIYCPPricePoint *> * _Nullable prices, NSError * _Nullable error))completion;

#pragma mark - Price Modification

/// 创建 IAP 价格计划（一次性提交所有地区的价格变更）
/// POST /v1/inAppPurchasePriceSchedules
/// @param iapId IAP 商品的 Apple ID（即 inAppPurchases 的 id）
/// @param baseTerritoryId 基准国家代码（如 "USA"）
/// @param basePricePointId 基准国家的价格点 ID
/// @param manualPrices 各地区的价格点数组，每个元素是 DIYCPPricePoint（包含 pricePointId 和 territory）
/// @param startDate 生效日期（传 nil 表示立即生效）
/// @param completion 完成回调
- (void)createIAPPriceScheduleForIAPId:(NSString *)iapId
                       baseTerritoryId:(NSString *)baseTerritoryId
                      basePricePointId:(NSString *)basePricePointId
                          manualPrices:(NSArray<DIYCPPricePoint *> *)manualPrices
                             startDate:(NSDate * _Nullable)startDate
                            completion:(void (^)(BOOL success, NSError * _Nullable error))completion;

/// 批量更新订阅商品的价格（逐地区提交）
/// POST /v1/subscriptionPrices
/// @param subscriptionId 订阅商品的 ID
/// @param pricePoints 各地区的价格点数组，每个元素是 DIYCPPricePoint
/// @param startDate 生效日期
/// @param preserveCurrentPrice 是否保留当前价格（YES = 新价格仅对新订阅者生效，现有订阅者保持原价；NO = 所有订阅者都将使用新价格）
/// @param progressBlock 进度回调（已完成数 / 总数）
/// @param completion 完成回调（返回失败的地区代码数组，空表示全部成功）
- (void)updateSubscriptionPricesForSubId:(NSString *)subscriptionId
                             pricePoints:(NSArray<DIYCPPricePoint *> *)pricePoints
                               startDate:(NSDate * _Nullable)startDate
                    preserveCurrentPrice:(BOOL)preserveCurrentPrice
                           progressBlock:(void (^)(NSInteger completed, NSInteger total))progressBlock
                              completion:(void (^)(NSArray<NSString *> *failedTerritories, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
