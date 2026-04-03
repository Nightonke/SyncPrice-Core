//
//  DIYCPMgr.h
//  ChangePrices
//
//  Created by Nightonke on 2026/3/16.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Error code: Product not configured with price (No price schedule on App Store Connect)
extern NSInteger const DIYCPMgrErrorCodeNoPriceSchedule;

#pragma mark - Models

@interface DIYCPApp : NSObject

@property (nonatomic, copy) NSString *appId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *bundleId;
@property (nonatomic, copy) NSString *sku;
@property (nonatomic, copy, nullable) NSString *iconURL;

@end

/// IAP product model (CONSUMABLE / NON_CONSUMABLE / NON_RENEWING_SUBSCRIPTION)
@interface DIYCPInAppPurchase : NSObject

@property (nonatomic, copy) NSString *iapId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *productId;
@property (nonatomic, copy) NSString *inAppPurchaseType; // CONSUMABLE, NON_CONSUMABLE, NON_RENEWING_SUBSCRIPTION
@property (nonatomic, copy) NSString *state;             // APPROVED, READY_TO_SUBMIT, etc.

@end

/// Auto-renewable subscription model
@interface DIYCPSubscription : NSObject

@property (nonatomic, copy) NSString *subscriptionId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *productId;
@property (nonatomic, copy) NSString *state;
@property (nonatomic, copy) NSString *subscriptionPeriod; // ONE_WEEK, ONE_MONTH, TWO_MONTHS, THREE_MONTHS, SIX_MONTHS, ONE_YEAR

@end

/// Subscription group model
@interface DIYCPSubscriptionGroup : NSObject

@property (nonatomic, copy) NSString *groupId;
@property (nonatomic, copy) NSString *referenceName;
@property (nonatomic, strong) NSArray<DIYCPSubscription *> *subscriptions;

@end

/// Territory/Country model
@interface DIYCPTerritory : NSObject

@property (nonatomic, copy) NSString *territoryId; // e.g. "USA", "CHN"
@property (nonatomic, copy) NSString *currency;    // e.g. "USD", "CNY"

@end

/// Price point model (price of a product in a specific region)
@interface DIYCPPricePoint : NSObject

@property (nonatomic, copy) NSString *pricePointId;
@property (nonatomic, copy) NSString *customerPrice; // Customer facing price
@property (nonatomic, copy) NSString *proceeds;      // Developer proceeds
@property (nonatomic, strong) DIYCPTerritory *territory;

@end

/// Current product price information (includes territory and price)
@interface DIYCPCurrentPrice : NSObject

@property (nonatomic, copy) NSString *startDate;
@property (nonatomic, strong) DIYCPPricePoint *manual; // Manually set price

@end

#pragma mark - Manager

@interface DIYCPMgr : NSObject

+ (instancetype)shared;

/// Clear cached JWT Token (called when credentials change)
- (void)invalidateToken;

/// Fetch all apps under the account
- (void)fetchAllAppsWithCompletion:(void (^)(NSArray<DIYCPApp *> * _Nullable apps, NSError * _Nullable error))completion;

/// Fetch IAP product list for a specific app
- (void)fetchInAppPurchasesForAppId:(NSString *)appId
                         completion:(void (^)(NSArray<DIYCPInAppPurchase *> * _Nullable iaps, NSError * _Nullable error))completion;

/// Fetch subscription group list for a specific app (each group contains its subscriptions)
- (void)fetchSubscriptionGroupsForAppId:(NSString *)appId
                             completion:(void (^)(NSArray<DIYCPSubscriptionGroup *> * _Nullable groups, NSError * _Nullable error))completion;

/// Fetch price points for IAP product in specified regions
/// @param territories Region code array to query (up to 10, e.g. @[@"USA", @"CHN", @"JPN"]), pass nil or empty array to query all regions
- (void)fetchIAPPricePointsForIAPId:(NSString *)iapId
                         territories:(NSArray<NSString *> * _Nullable)territories
                          completion:(void (^)(NSArray<DIYCPPricePoint *> * _Nullable pricePoints, NSError * _Nullable error))completion;

/// Fetch equalization prices for IAP price point
/// Given a base price point ID, returns equivalent prices in all other countries/regions (one per region)
/// GET /v1/inAppPurchasePricePoints/{id}/equalizations?include=territory
/// @param pricePointId Base price point ID (e.g., USA's pricePointId)
/// @param completion Completion callback, returns array of equivalent price points for all regions
- (void)fetchIAPEqualizationsForPricePointId:(NSString *)pricePointId
                                  completion:(void (^)(NSArray<DIYCPPricePoint *> * _Nullable pricePoints, NSError * _Nullable error))completion;

/// Fetch current pricing for IAP product across all regions
- (void)fetchIAPCurrentPricesForIAPId:(NSString *)iapId
                           completion:(void (^)(NSArray<DIYCPPricePoint *> * _Nullable prices, NSError * _Nullable error))completion;

/// Fetch price points for subscription product in all regions
- (void)fetchSubscriptionPricePointsForSubId:(NSString *)subscriptionId
                                   territory:(NSString * _Nullable)filterTerritory
                                  completion:(void (^)(NSArray<DIYCPPricePoint *> * _Nullable pricePoints, NSError * _Nullable error))completion;

/// Fetch equalization prices for subscription price point
/// Given a base price point ID, returns equivalent prices in all other countries/regions (one per region)
/// GET /v1/subscriptionPricePoints/{id}/equalizations?include=territory
/// @param pricePointId Base price point ID (e.g., USA's pricePointId)
/// @param completion Completion callback, returns array of equivalent price points for all regions
- (void)fetchSubscriptionEqualizationsForPricePointId:(NSString *)pricePointId
                                           completion:(void (^)(NSArray<DIYCPPricePoint *> * _Nullable pricePoints, NSError * _Nullable error))completion;

/// Fetch current pricing for subscription product across all regions
- (void)fetchSubscriptionCurrentPricesForSubId:(NSString *)subscriptionId
                                    completion:(void (^)(NSArray<DIYCPPricePoint *> * _Nullable prices, NSError * _Nullable error))completion;

#pragma mark - Price Modification

/// Create IAP price schedule (submit price changes for all regions at once)
/// POST /v1/inAppPurchasePriceSchedules
/// @param iapId IAP product Apple ID (i.e., inAppPurchases id)
/// @param baseTerritoryId Base country code (e.g., "USA")
/// @param basePricePointId Base country price point ID
/// @param manualPrices Array of price points for each region, each element is DIYCPPricePoint (contains pricePointId and territory)
/// @param startDate Effective date (pass nil for immediate effect)
/// @param completion Completion callback
- (void)createIAPPriceScheduleForIAPId:(NSString *)iapId
                       baseTerritoryId:(NSString *)baseTerritoryId
                      basePricePointId:(NSString *)basePricePointId
                          manualPrices:(NSArray<DIYCPPricePoint *> *)manualPrices
                             startDate:(NSDate * _Nullable)startDate
                            completion:(void (^)(BOOL success, NSError * _Nullable error))completion;

/// Batch update subscription product prices (submit region by region)
/// POST /v1/subscriptionPrices
/// @param subscriptionId Subscription product ID
/// @param pricePoints Array of price points for each region, each element is DIYCPPricePoint
/// @param startDate Effective date
/// @param preserveCurrentPrice Whether to preserve current price (YES = new price only for new subscribers, existing subscribers keep original price; NO = all subscribers use new price)
/// @param progressBlock Progress callback (completed / total)
/// @param completion Completion callback (returns array of failed region codes, empty means all successful)
- (void)updateSubscriptionPricesForSubId:(NSString *)subscriptionId
                             pricePoints:(NSArray<DIYCPPricePoint *> *)pricePoints
                               startDate:(NSDate * _Nullable)startDate
                    preserveCurrentPrice:(BOOL)preserveCurrentPrice
                           progressBlock:(void (^)(NSInteger completed, NSInteger total))progressBlock
                              completion:(void (^)(NSArray<NSString *> *failedTerritories, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END
