//
//  DIYCPMgr.m
//  ChangePrices
//
//  Created by viktorhuang on 2026/3/16.
//

#import "DIYCPMgr_Private.h"
#import "DIYCPMgr.h"
#import "DIYCPMgr+NetUtil.h"
#import "DIYSettings.h"
#import "ChangePrices-Swift.h"

NSInteger const DIYCPMgrErrorCodeNoPriceSchedule = 10404;

@implementation DIYCPApp
@end

@implementation DIYCPInAppPurchase
@end

@implementation DIYCPSubscription
@end

@implementation DIYCPSubscriptionGroup
@end

@implementation DIYCPTerritory
@end

@implementation DIYCPPricePoint
@end

@implementation DIYCPCurrentPrice
@end

@interface DIYCPMgr ()

@property (nonatomic, strong) NSString *cachedToken;
@property (nonatomic, assign) NSTimeInterval tokenExpireTime;

@end

@implementation DIYCPMgr

+ (instancetype)shared
{
    static DIYCPMgr *sharedVC = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedVC = [[self alloc] init];
    });
    return sharedVC;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        _cachedToken = nil;
        _tokenExpireTime = 0;
    }
    return self;
}

#pragma mark - Public

- (void)fetchAllAppsWithCompletion:(void (^)(NSArray<DIYCPApp *> * _Nullable, NSError * _Nullable))completion
{
    DIY_WEAK_SELF(self);
    [self startNetTaskWithURLString:@"https://api.appstoreconnect.apple.com/v1/apps"
                         httpMethod:@"GET"
                       sendJsonData:nil
                         completion:^(NSDictionary * _Nullable json, NSError * _Nullable error) {
        
        DIY_STRONG_SELF(self);
        NSArray *dataArray = json[@"data"];
        NSMutableArray<DIYCPApp *> *apps = [NSMutableArray array];
        for (NSDictionary *item in dataArray)
        {
            if (![item isKindOfClass:[NSDictionary class]])
            {
                continue;
            }
            
            DIYCPApp *app = [[DIYCPApp alloc] init];
            app.appId = [item[@"id"] isKindOfClass:[NSString class]] ? item[@"id"] : @"";
            
            NSDictionary *attributes = item[@"attributes"];
            if ([attributes isKindOfClass:[NSDictionary class]])
            {
                app.name = [attributes[@"name"] isKindOfClass:[NSString class]] ? attributes[@"name"] : @"";
                app.bundleId = [attributes[@"bundleId"] isKindOfClass:[NSString class]] ? attributes[@"bundleId"] : @"";
                app.sku = [attributes[@"sku"] isKindOfClass:[NSString class]] ? attributes[@"sku"] : @"";
            }
            
            [apps addObject:app];
        }
        
        // 通过 iTunes Lookup API 批量获取 app 图标
        [self fetchIconURLsForApps:apps completion:^(NSArray<DIYCPApp *> *appsWithIcons) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion)
                {
                    completion(appsWithIcons, nil);
                }
            });
        }];
        
    }];
}

#pragma mark - Public: IAP Products

- (void)fetchInAppPurchasesForAppId:(NSString *)appId
                         completion:(void (^)(NSArray<DIYCPInAppPurchase *> * _Nullable, NSError * _Nullable))completion
{
    NSString *urlString = [NSString stringWithFormat:@"https://api.appstoreconnect.apple.com/v1/apps/%@/inAppPurchasesV2?limit=200", appId];
    
    [self startNetTaskWithURLString:urlString
                         httpMethod:@"GET"
                       sendJsonData:nil
                         completion:^(NSDictionary * _Nullable json, NSError * _Nullable error) {
        if (error)
        {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, error); });
            return;
        }
        
        NSArray *dataArray = json[@"data"];
        NSMutableArray<DIYCPInAppPurchase *> *iaps = [NSMutableArray array];
        
        for (NSDictionary *item in dataArray)
        {
            if (![item isKindOfClass:[NSDictionary class]]) continue;
            
            DIYCPInAppPurchase *iap = [[DIYCPInAppPurchase alloc] init];
            iap.iapId = [item[@"id"] isKindOfClass:[NSString class]] ? item[@"id"] : @"";
            
            NSDictionary *attr = item[@"attributes"];
            if ([attr isKindOfClass:[NSDictionary class]])
            {
                iap.name = [attr[@"name"] isKindOfClass:[NSString class]] ? attr[@"name"] : @"";
                iap.productId = [attr[@"productId"] isKindOfClass:[NSString class]] ? attr[@"productId"] : @"";
                iap.inAppPurchaseType = [attr[@"inAppPurchaseType"] isKindOfClass:[NSString class]] ? attr[@"inAppPurchaseType"] : @"";
                iap.state = [attr[@"state"] isKindOfClass:[NSString class]] ? attr[@"state"] : @"";
            }
            [iaps addObject:iap];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion([iaps copy], nil); });
    }];
}

#pragma mark - Public: Subscription Groups

- (void)fetchSubscriptionGroupsForAppId:(NSString *)appId
                             completion:(void (^)(NSArray<DIYCPSubscriptionGroup *> * _Nullable, NSError * _Nullable))completion
{
    NSString *urlString = [NSString stringWithFormat:@"https://api.appstoreconnect.apple.com/v1/apps/%@/subscriptionGroups?limit=200", appId];
    
    DIY_WEAK_SELF(self);
    [self startNetTaskWithURLString:urlString
                         httpMethod:@"GET"
                       sendJsonData:nil
                         completion:^(NSDictionary * _Nullable json, NSError * _Nullable error) {
        DIY_STRONG_SELF(self);
        
        if (error)
        {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, error); });
            return;
        }
        
        NSArray *dataArray = json[@"data"];
        NSMutableArray<DIYCPSubscriptionGroup *> *groups = [NSMutableArray array];
        
        for (NSDictionary *item in dataArray)
        {
            if (![item isKindOfClass:[NSDictionary class]]) continue;
            
            DIYCPSubscriptionGroup *group = [[DIYCPSubscriptionGroup alloc] init];
            group.groupId = [item[@"id"] isKindOfClass:[NSString class]] ? item[@"id"] : @"";
            
            NSDictionary *attr = item[@"attributes"];
            if ([attr isKindOfClass:[NSDictionary class]])
            {
                group.referenceName = [attr[@"referenceName"] isKindOfClass:[NSString class]] ? attr[@"referenceName"] : @"";
            }
            group.subscriptions = @[];
            [groups addObject:group];
        }
        
        // 2. 并发获取每个分组下的订阅列表
        [self fetchSubscriptionsForGroups:groups completion:^(NSArray<DIYCPSubscriptionGroup *> *groupsWithSubs) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(groupsWithSubs, nil); });
        }];
    }];
}

- (void)fetchSubscriptionsForGroups:(NSArray<DIYCPSubscriptionGroup *> *)groups
                         completion:(void (^)(NSArray<DIYCPSubscriptionGroup *> *))completion
{
    if (groups.count == 0)
    {
        if (completion) completion(groups);
        return;
    }
    
    dispatch_group_t dispatchGroup = dispatch_group_create();
    
    for (DIYCPSubscriptionGroup *group in groups)
    {
        if (group.groupId.length == 0) continue;
        
        dispatch_group_enter(dispatchGroup);
        
        NSString *urlString = [NSString stringWithFormat:@"https://api.appstoreconnect.apple.com/v1/subscriptionGroups/%@/subscriptions?limit=200", group.groupId];
        
        [self startNetTaskWithURLString:urlString
                             httpMethod:@"GET"
                           sendJsonData:nil
                             completion:^(NSDictionary * _Nullable json, NSError * _Nullable error) {
            if (!error && json)
            {
                NSArray *dataArray = json[@"data"];
                NSMutableArray<DIYCPSubscription *> *subs = [NSMutableArray array];
                
                for (NSDictionary *item in dataArray)
                {
                    if (![item isKindOfClass:[NSDictionary class]]) continue;
                    
                    DIYCPSubscription *sub = [[DIYCPSubscription alloc] init];
                    sub.subscriptionId = [item[@"id"] isKindOfClass:[NSString class]] ? item[@"id"] : @"";
                    
                    NSDictionary *attr = item[@"attributes"];
                    if ([attr isKindOfClass:[NSDictionary class]])
                    {
                        sub.name = [attr[@"name"] isKindOfClass:[NSString class]] ? attr[@"name"] : @"";
                        sub.productId = [attr[@"productId"] isKindOfClass:[NSString class]] ? attr[@"productId"] : @"";
                        sub.state = [attr[@"state"] isKindOfClass:[NSString class]] ? attr[@"state"] : @"";
                        sub.subscriptionPeriod = [attr[@"subscriptionPeriod"] isKindOfClass:[NSString class]] ? attr[@"subscriptionPeriod"] : @"";
                    }
                    [subs addObject:sub];
                }
                group.subscriptions = [subs copy];
            }
            dispatch_group_leave(dispatchGroup);
        }];
    }
    
    dispatch_group_notify(dispatchGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (completion) completion(groups);
    });
}

#pragma mark - Public: IAP Price Points

- (void)fetchIAPPricePointsForIAPId:(NSString *)iapId
                         territories:(NSArray<NSString *> *)territories
                          completion:(void (^)(NSArray<DIYCPPricePoint *> * _Nullable, NSError * _Nullable))completion
{
    // 使用 v2 端点获取 IAP 的价格点，include territory
    // filter[territory] 支持逗号分隔的多个地区代码，最多10个
    NSString *urlString = [NSString stringWithFormat:
        @"https://api.appstoreconnect.apple.com/v2/inAppPurchases/%@/pricePoints?include=territory&limit=8000",
        iapId];
    if (territories.count > 0)
    {
        NSArray *limitedTerritories = territories;
        if (territories.count > 5)
        {
            limitedTerritories = [territories subarrayWithRange:NSMakeRange(0, 5)];
            NSLog(@"[DIYCPMgr] Warning: filter[territory] supports at most 5 values per batch, truncating from %lu to 5", (unsigned long)territories.count);
        }
        NSString *joined = [limitedTerritories componentsJoinedByString:@","];
        urlString = [urlString stringByAppendingFormat:@"&filter[territory]=%@", joined];
    }
    
    [self fetchAllPagesOfPricePointsFromURL:urlString accumulated:@[] completion:completion];
}

- (void)fetchIAPEqualizationsForPricePointId:(NSString *)pricePointId
                                  completion:(void (^)(NSArray<DIYCPPricePoint *> * _Nullable, NSError * _Nullable))completion
{
    // IAP Equalizations API: 给定一个价格点 ID，返回所有其他地区的等价价格
    // 返回格式和 pricePoints 完全一致（data 数组 + included territories），可复用解析逻辑
    NSString *urlString = [NSString stringWithFormat:
        @"https://api.appstoreconnect.apple.com/v1/inAppPurchasePricePoints/%@/equalizations?include=territory&limit=200",
        pricePointId];
    
    [self fetchAllPagesOfPricePointsFromURL:urlString accumulated:@[] completion:completion];
}

- (void)fetchIAPCurrentPricesForIAPId:(NSString *)iapId
                           completion:(void (^)(NSArray<DIYCPPricePoint *> * _Nullable, NSError * _Nullable))completion
{
    // Step 1: 先获取 iapPriceSchedule 拿到 schedule 的 id
    NSString *urlString = [NSString stringWithFormat:
        @"https://api.appstoreconnect.apple.com/v2/inAppPurchases/%@/iapPriceSchedule",
        iapId];
    
    DIY_WEAK_SELF(self);
    [self startNetTaskWithURLString:urlString
                         httpMethod:@"GET"
                       sendJsonData:nil
                         completion:^(NSDictionary * _Nullable json, NSError * _Nullable error) {
        DIY_STRONG_SELF(self);
        
        if (error)
        {
            // 检测 404 NOT_FOUND —— 说明该商品尚未在 App Store Connect 配置价格
            if (error.code == 404)
            {
                NSError *noPriceError = [NSError errorWithDomain:@"DIYCPMgr"
                                                            code:DIYCPMgrErrorCodeNoPriceSchedule
                                                        userInfo:@{NSLocalizedDescriptionKey: @"该商品尚未在 App Store Connect 上配置价格。请先在 App Store Connect 中为该商品设置价格后再试。"}];
                dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, noPriceError); });
                return;
            }
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, error); });
            return;
        }
        
        NSDictionary *dataObj = json[@"data"];
        NSString *scheduleId = dataObj[@"id"];
        
        if (!scheduleId)
        {
            NSError *parseError = [NSError errorWithDomain:@"DIYCPMgr" code:-2
                                                  userInfo:@{NSLocalizedDescriptionKey: @"Failed to get price schedule ID"}];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, parseError); });
            return;
        }
        
        // Step 2: 先获取 manualPrices（手动设置的价格，如美国基准价和中国独立价），再获取 automaticPrices（Apple 自动计算的其他地区价格）
        // manualPrices 优先，automaticPrices 补充剩余地区
        NSString *manualPricesURL = [NSString stringWithFormat:
            @"https://api.appstoreconnect.apple.com/v1/inAppPurchasePriceSchedules/%@/manualPrices?include=inAppPurchasePricePoint,territory&limit=200",
            scheduleId];
        
        [self fetchIAPCurrentPricesPageFromURL:manualPricesURL accumulated:@[] completion:^(NSArray<DIYCPPricePoint *> * _Nullable manualResults, NSError * _Nullable manualError) {
            if (manualError)
            {
                if (completion) completion(nil, manualError);
                return;
            }
            
            // Step 3: 用 automaticPrices 子端点获取 Apple 自动计算的其他地区价格
            // accumulated 传入 manualResults，seenTerritories 会自动去重（手动价格优先）
            NSString *autoPricesURL = [NSString stringWithFormat:
                @"https://api.appstoreconnect.apple.com/v1/inAppPurchasePriceSchedules/%@/automaticPrices?include=inAppPurchasePricePoint,territory&limit=200",
                scheduleId];
            
            [self fetchIAPCurrentPricesPageFromURL:autoPricesURL accumulated:manualResults completion:completion];
        }];
    }];
}

#pragma mark - Public: Subscription Price Points

- (void)fetchSubscriptionPricePointsForSubId:(NSString *)subscriptionId
                                   territory:(NSString *)filterTerritory
                                  completion:(void (^)(NSArray<DIYCPPricePoint *> * _Nullable, NSError * _Nullable))completion
{
    // Subscription 是 v1 资源，pricePoints 端点在 v1 下（不同于 IAP 的 v2）
    NSString *urlString = [NSString stringWithFormat:
        @"https://api.appstoreconnect.apple.com/v1/subscriptions/%@/pricePoints?include=territory&limit=8000",
        subscriptionId];
    if (filterTerritory.length > 0)
    {
        // filter[territory] 支持逗号分隔的多个地区代码
        NSArray *territories = [filterTerritory componentsSeparatedByString:@","];
        if (territories.count > 5)
        {
            territories = [territories subarrayWithRange:NSMakeRange(0, 5)];
            NSLog(@"[DIYCPMgr] Warning: filter[territory] supports at most 5 values per batch, truncating from %lu to 5", (unsigned long)[filterTerritory componentsSeparatedByString:@","].count);
        }
        NSString *joined = [territories componentsJoinedByString:@","];
        urlString = [urlString stringByAppendingFormat:@"&filter[territory]=%@", joined];
    }
    
    [self fetchAllPagesOfPricePointsFromURL:urlString accumulated:@[] completion:completion];
}

- (void)fetchSubscriptionEqualizationsForPricePointId:(NSString *)pricePointId
                                           completion:(void (^)(NSArray<DIYCPPricePoint *> * _Nullable, NSError * _Nullable))completion
{
    // Equalizations API: 给定一个价格点 ID，返回所有其他地区的等价价格
    // 返回格式和 pricePoints 完全一致（data 数组 + included territories），可复用解析逻辑
    NSString *urlString = [NSString stringWithFormat:
        @"https://api.appstoreconnect.apple.com/v1/subscriptionPricePoints/%@/equalizations?include=territory&limit=200",
        pricePointId];
    
    [self fetchAllPagesOfPricePointsFromURL:urlString accumulated:@[] completion:completion];
}

- (void)fetchSubscriptionCurrentPricesForSubId:(NSString *)subscriptionId
                                    completion:(void (^)(NSArray<DIYCPPricePoint *> * _Nullable, NSError * _Nullable))completion
{
    NSString *urlString = [NSString stringWithFormat:
        @"https://api.appstoreconnect.apple.com/v1/subscriptions/%@/prices?include=subscriptionPricePoint,territory&limit=200",
        subscriptionId];
    
    [self fetchSubscriptionCurrentPricesFromURL:urlString accumulated:@[] completion:completion];
}

#pragma mark - Private: Paginated Price Point Fetching

- (void)fetchAllPagesOfPricePointsFromURL:(NSString *)urlString
                              accumulated:(NSArray<DIYCPPricePoint *> *)accumulated
                               completion:(void (^)(NSArray<DIYCPPricePoint *> * _Nullable, NSError * _Nullable))completion
{
    DIY_WEAK_SELF(self);
    [self startNetTaskWithURLString:urlString
                         httpMethod:@"GET"
                       sendJsonData:nil
                         completion:^(NSDictionary * _Nullable json, NSError * _Nullable error) {
        DIY_STRONG_SELF(self);
        
        if (error)
        {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, error); });
            return;
        }
        
        NSArray *dataArray = json[@"data"];
        
        // Build territory lookup from "included"
        NSMutableDictionary<NSString *, DIYCPTerritory *> *territoryMap = [NSMutableDictionary dictionary];
        NSArray *included = json[@"included"];
        if ([included isKindOfClass:[NSArray class]])
        {
            for (NSDictionary *inc in included)
            {
                if (![inc isKindOfClass:[NSDictionary class]]) continue;
                if ([inc[@"type"] isEqualToString:@"territories"])
                {
                    DIYCPTerritory *t = [[DIYCPTerritory alloc] init];
                    t.territoryId = inc[@"id"] ?: @"";
                    NSDictionary *attr = inc[@"attributes"];
                    if ([attr isKindOfClass:[NSDictionary class]])
                    {
                        t.currency = attr[@"currency"] ?: @"";
                    }
                    territoryMap[t.territoryId] = t;
                }
            }
        }
        
        NSMutableArray<DIYCPPricePoint *> *results = [NSMutableArray arrayWithArray:accumulated];
        for (NSDictionary *item in dataArray)
        {
            if (![item isKindOfClass:[NSDictionary class]]) continue;
            
            DIYCPPricePoint *pp = [[DIYCPPricePoint alloc] init];
            pp.pricePointId = item[@"id"] ?: @"";
            
            NSDictionary *attr = item[@"attributes"];
            if ([attr isKindOfClass:[NSDictionary class]])
            {
                pp.customerPrice = attr[@"customerPrice"] ?: @"0";
                pp.proceeds = attr[@"proceeds"] ?: @"0";
            }
            
            // Resolve territory relationship
            NSDictionary *rels = item[@"relationships"];
            NSDictionary *terRel = rels[@"territory"];
            NSDictionary *terData = terRel[@"data"];
            if ([terData isKindOfClass:[NSDictionary class]])
            {
                NSString *tId = terData[@"id"];
                pp.territory = territoryMap[tId];
            }
            
            [results addObject:pp];
        }
        
        // Check for next page
        NSDictionary *links = json[@"links"];
        NSString *nextURL = links[@"next"];
        if ([nextURL isKindOfClass:[NSString class]] && nextURL.length > 0)
        {
            [self fetchAllPagesOfPricePointsFromURL:nextURL accumulated:results completion:completion];
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion([results copy], nil); });
        }
    }];
}

#pragma mark - Private: IAP Current Prices (paginated via manualPrices sub-endpoint)

- (void)fetchIAPCurrentPricesPageFromURL:(NSString *)urlString
                             accumulated:(NSArray<DIYCPPricePoint *> *)accumulated
                              completion:(void (^)(NSArray<DIYCPPricePoint *> * _Nullable, NSError * _Nullable))completion
{
    DIY_WEAK_SELF(self);
    [self startNetTaskWithURLString:urlString
                         httpMethod:@"GET"
                       sendJsonData:nil
                         completion:^(NSDictionary * _Nullable json, NSError * _Nullable error) {
        DIY_STRONG_SELF(self);
        
        if (error)
        {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, error); });
            return;
        }
        
        // Response format from /v1/inAppPurchasePriceSchedules/{id}/manualPrices?include=inAppPurchasePricePoint,territory
        // - data: array of inAppPurchasePrices objects
        //   each has: attributes (startDate, endDate, manual), relationships (inAppPurchasePricePoint, territory)
        // - included: array of inAppPurchasePricePoints (with customerPrice, proceeds) and territories (with currency)
        // - links.next: next page URL
        
        // Build lookup maps from "included"
        NSMutableDictionary<NSString *, NSDictionary *> *pricePointAttrMap = [NSMutableDictionary dictionary]; // ppId -> attributes
        NSMutableDictionary<NSString *, NSString *> *pricePointTerritoryMap = [NSMutableDictionary dictionary]; // ppId -> territoryId
        NSMutableDictionary<NSString *, DIYCPTerritory *> *territoryMap = [NSMutableDictionary dictionary]; // territoryId -> territory
        
        NSArray *included = json[@"included"];
        if ([included isKindOfClass:[NSArray class]])
        {
            for (NSDictionary *inc in included)
            {
                if (![inc isKindOfClass:[NSDictionary class]]) continue;
                NSString *type = inc[@"type"];
                NSString *incId = inc[@"id"];
                
                if ([type isEqualToString:@"inAppPurchasePricePoints"])
                {
                    NSDictionary *attr = inc[@"attributes"];
                    if ([attr isKindOfClass:[NSDictionary class]])
                    {
                        pricePointAttrMap[incId] = attr;
                    }
                    NSDictionary *rels = inc[@"relationships"];
                    NSDictionary *terData = rels[@"territory"][@"data"];
                    if ([terData isKindOfClass:[NSDictionary class]])
                    {
                        pricePointTerritoryMap[incId] = terData[@"id"];
                    }
                }
                else if ([type isEqualToString:@"territories"])
                {
                    DIYCPTerritory *t = [[DIYCPTerritory alloc] init];
                    t.territoryId = incId ?: @"";
                    NSDictionary *attr = inc[@"attributes"];
                    if ([attr isKindOfClass:[NSDictionary class]])
                    {
                        t.currency = attr[@"currency"] ?: @"";
                    }
                    territoryMap[t.territoryId] = t;
                }
            }
        }
        
        // Parse data array - each item is an inAppPurchasePrices object
        NSArray *dataArray = json[@"data"];
        
        NSMutableArray<DIYCPPricePoint *> *results = [NSMutableArray arrayWithArray:accumulated];
        NSMutableSet<NSString *> *seenTerritories = [NSMutableSet set];
        for (DIYCPPricePoint *existing in accumulated)
        {
            if (existing.territory.territoryId)
            {
                [seenTerritories addObject:existing.territory.territoryId];
            }
        }
        
        if ([dataArray isKindOfClass:[NSArray class]])
        {
            for (NSDictionary *priceObj in dataArray)
            {
                if (![priceObj isKindOfClass:[NSDictionary class]]) continue;
                
                NSDictionary *rels = priceObj[@"relationships"];
                
                // Get pricePoint id from relationship
                NSString *ppId = rels[@"inAppPurchasePricePoint"][@"data"][@"id"];
                if (!ppId) continue;
                
                // Get territory id from relationship
                NSString *terId = rels[@"territory"][@"data"][@"id"];
                if (!terId)
                {
                    // Fallback: get territory from pricePoint's relationship
                    terId = pricePointTerritoryMap[ppId];
                }
                if (!terId) continue;
                
                // Skip duplicate territories (keep first one)
                if ([seenTerritories containsObject:terId]) continue;
                
                // Get pricePoint attributes from included
                NSDictionary *ppAttr = pricePointAttrMap[ppId];
                DIYCPTerritory *territory = territoryMap[terId];
                if (!territory) continue;
                
                DIYCPPricePoint *pp = [[DIYCPPricePoint alloc] init];
                pp.pricePointId = ppId;
                pp.customerPrice = ppAttr[@"customerPrice"] ?: @"0";
                pp.proceeds = ppAttr[@"proceeds"] ?: @"0";
                pp.territory = territory;
                
                [results addObject:pp];
                [seenTerritories addObject:terId];
            }
        }
        
        // Check for next page
        NSString *nextPageURL = nil;
        NSDictionary *links = json[@"links"];
        NSString *nextLink = links[@"next"];
        if ([nextLink isKindOfClass:[NSString class]] && nextLink.length > 0)
        {
            nextPageURL = nextLink;
        }
        
        if (nextPageURL)
        {
            [self fetchIAPCurrentPricesPageFromURL:nextPageURL accumulated:results completion:completion];
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion([results copy], nil); });
        }
    }];
}

#pragma mark - Private: Subscription Current Prices

- (void)fetchSubscriptionCurrentPricesFromURL:(NSString *)urlString
                                  accumulated:(NSArray<DIYCPPricePoint *> *)accumulated
                                   completion:(void (^)(NSArray<DIYCPPricePoint *> * _Nullable, NSError * _Nullable))completion
{
    DIY_WEAK_SELF(self);
    [self startNetTaskWithURLString:urlString
                         httpMethod:@"GET"
                       sendJsonData:nil
                         completion:^(NSDictionary * _Nullable json, NSError * _Nullable error) {
        DIY_STRONG_SELF(self);
        
        if (error)
        {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, error); });
            return;
        }
        
        // Build lookup maps
        NSMutableDictionary<NSString *, NSDictionary *> *ppAttrMap = [NSMutableDictionary dictionary];
        NSMutableDictionary<NSString *, NSString *> *ppTerMap = [NSMutableDictionary dictionary];
        NSMutableDictionary<NSString *, DIYCPTerritory *> *terMap = [NSMutableDictionary dictionary];
        
        NSArray *included = json[@"included"];
        if ([included isKindOfClass:[NSArray class]])
        {
            for (NSDictionary *inc in included)
            {
                if (![inc isKindOfClass:[NSDictionary class]]) continue;
                NSString *type = inc[@"type"];
                NSString *incId = inc[@"id"];
                
                if ([type isEqualToString:@"subscriptionPricePoints"])
                {
                    NSDictionary *attr = inc[@"attributes"];
                    if ([attr isKindOfClass:[NSDictionary class]])
                    {
                        ppAttrMap[incId] = attr;
                    }
                    NSDictionary *rels = inc[@"relationships"];
                    NSDictionary *terData = rels[@"territory"][@"data"];
                    if ([terData isKindOfClass:[NSDictionary class]])
                    {
                        ppTerMap[incId] = terData[@"id"];
                    }
                }
                else if ([type isEqualToString:@"territories"])
                {
                    DIYCPTerritory *t = [[DIYCPTerritory alloc] init];
                    t.territoryId = incId ?: @"";
                    NSDictionary *attr = inc[@"attributes"];
                    if ([attr isKindOfClass:[NSDictionary class]])
                    {
                        t.currency = attr[@"currency"] ?: @"";
                    }
                    terMap[t.territoryId] = t;
                }
            }
        }
        
        NSMutableArray<DIYCPPricePoint *> *results = [NSMutableArray arrayWithArray:accumulated];
        NSMutableSet<NSString *> *seenTerritories = [NSMutableSet set];
        for (DIYCPPricePoint *existing in accumulated)
        {
            if (existing.territory.territoryId)
            {
                [seenTerritories addObject:existing.territory.territoryId];
            }
        }
        
        NSArray *dataArray = json[@"data"];
        for (NSDictionary *item in dataArray)
        {
            if (![item isKindOfClass:[NSDictionary class]]) continue;
            
            NSDictionary *rels = item[@"relationships"];
            NSDictionary *ppData = rels[@"subscriptionPricePoint"][@"data"];
            if (![ppData isKindOfClass:[NSDictionary class]]) continue;
            
            NSString *ppId = ppData[@"id"];
            
            // Get territory id from relationship (direct), fallback to pricePoint's relationship
            NSString *terId = rels[@"territory"][@"data"][@"id"];
            if (!terId)
            {
                terId = ppTerMap[ppId];
            }
            if (!terId) continue;
            
            // Skip duplicate territories (keep first one)
            if ([seenTerritories containsObject:terId]) continue;
            
            NSDictionary *ppAttr = ppAttrMap[ppId];
            DIYCPTerritory *territory = terMap[terId];
            if (!territory) continue;
            
            DIYCPPricePoint *pp = [[DIYCPPricePoint alloc] init];
            pp.pricePointId = ppId ?: @"";
            pp.customerPrice = ppAttr[@"customerPrice"] ?: @"0";
            pp.proceeds = ppAttr[@"proceeds"] ?: @"0";
            pp.territory = territory;
            
            [results addObject:pp];
            [seenTerritories addObject:terId];
        }
        
        // Check for next page
        NSDictionary *links = json[@"links"];
        NSString *nextURL = links[@"next"];
        if ([nextURL isKindOfClass:[NSString class]] && nextURL.length > 0)
        {
            [self fetchSubscriptionCurrentPricesFromURL:nextURL accumulated:results completion:completion];
        }
        else
        {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion([results copy], nil); });
        }
    }];
}

#pragma mark - Public: Create IAP Price Schedule

- (void)createIAPPriceScheduleForIAPId:(NSString *)iapId
                       baseTerritoryId:(NSString *)baseTerritoryId
                      basePricePointId:(NSString *)basePricePointId
                          manualPrices:(NSArray<DIYCPPricePoint *> *)manualPrices
                             startDate:(NSDate * _Nullable)startDate
                            completion:(void (^)(BOOL success, NSError * _Nullable error))completion
{
    // 格式化生效日期
    NSString *startDateStr = nil;
    if (startDate)
    {
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"yyyy-MM-dd";
        fmt.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        startDateStr = [fmt stringFromDate:startDate];
    }
    
    // 构建 manualPrices relationship data 和 included 数组
    NSMutableArray *manualPricesRelData = [NSMutableArray array];
    NSMutableArray *includedArray = [NSMutableArray array];
    
    // 首先添加基准国家的价格点（基准国家必须在 manualPrices 中）
    // Apple API 要求 included 中的 placeholder id 必须使用 ${local-id} 格式
    NSInteger priceIndex = 0;
    NSString *basePlaceholderId = [NSString stringWithFormat:@"${price%ld}", (long)priceIndex++];
    [manualPricesRelData addObject:@{
        @"type": @"inAppPurchasePrices",
        @"id": basePlaceholderId,
    }];
    
    NSMutableDictionary *baseIncluded = [NSMutableDictionary dictionary];
    baseIncluded[@"id"] = basePlaceholderId;
    baseIncluded[@"type"] = @"inAppPurchasePrices";
    // Apple 要求基准国家的 startDate 必须为 null（立即生效，覆盖整个时间线）
    baseIncluded[@"attributes"] = @{
        @"startDate": [NSNull null],
        @"endDate": [NSNull null],
    };
    baseIncluded[@"relationships"] = @{
        @"inAppPurchasePricePoint": @{
            @"data": @{
                @"id": basePricePointId,
                @"type": @"inAppPurchasePricePoints",
            }
        },
        @"inAppPurchaseV2": @{
            @"data": @{
                @"id": iapId,
                @"type": @"inAppPurchases",
            }
        },
    };
    [includedArray addObject:baseIncluded];
    
    // 添加其他地区的手动价格
    for (DIYCPPricePoint *pp in manualPrices)
    {
        // 跳过基准国家（已在上面添加）
        if ([pp.territory.territoryId isEqualToString:baseTerritoryId]) continue;
        
        NSString *placeholderId = [NSString stringWithFormat:@"${price%ld}", (long)priceIndex++];
        
        [manualPricesRelData addObject:@{
            @"type": @"inAppPurchasePrices",
            @"id": placeholderId,
        }];
        
        NSMutableDictionary *included = [NSMutableDictionary dictionary];
        included[@"id"] = placeholderId;
        included[@"type"] = @"inAppPurchasePrices";
        included[@"attributes"] = @{
            @"startDate": startDateStr ?: [NSNull null],
            @"endDate": [NSNull null],
        };
        included[@"relationships"] = @{
            @"inAppPurchasePricePoint": @{
                @"data": @{
                    @"id": pp.pricePointId,
                    @"type": @"inAppPurchasePricePoints",
                }
            },
            @"inAppPurchaseV2": @{
                @"data": @{
                    @"id": iapId,
                    @"type": @"inAppPurchases",
                }
            },
        };
        [includedArray addObject:included];
    }
    
    // 构建请求体
    NSDictionary *body = @{
        @"data": @{
            @"type": @"inAppPurchasePriceSchedules",
            @"relationships": @{
                @"inAppPurchase": @{
                    @"data": @{
                        @"type": @"inAppPurchases",
                        @"id": iapId,
                    }
                },
                @"baseTerritory": @{
                    @"data": @{
                        @"type": @"territories",
                        @"id": baseTerritoryId,
                    }
                },
                @"manualPrices": @{
                    @"data": manualPricesRelData,
                },
            },
        },
        @"included": includedArray,
    };
    
    NSError *jsonError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];
    if (jsonError)
    {
        if (completion) completion(NO, jsonError);
        return;
    }
    
    NSLog(@"[DIYCPMgr] Creating IAP price schedule for %@, base=%@, %lu manual prices",
          iapId, baseTerritoryId, (unsigned long)manualPrices.count);
    
    [self startNetTaskWithURLString:@"https://api.appstoreconnect.apple.com/v1/inAppPurchasePriceSchedules"
                         httpMethod:@"POST"
                       sendJsonData:jsonData
                         completion:^(NSDictionary * _Nullable json, NSError * _Nullable error) {
        if (error)
        {
            NSLog(@"[DIYCPMgr] IAP price schedule error: %@", error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(NO, error); });
        }
        else
        {
            NSLog(@"[DIYCPMgr] IAP price schedule created successfully");
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(YES, nil); });
        }
    }];
}

#pragma mark - Public: Update Subscription Prices

- (void)updateSubscriptionPricesForSubId:(NSString *)subscriptionId
                             pricePoints:(NSArray<DIYCPPricePoint *> *)pricePoints
                               startDate:(NSDate * _Nullable)startDate
                    preserveCurrentPrice:(BOOL)preserveCurrentPrice
                           progressBlock:(void (^)(NSInteger completed, NSInteger total))progressBlock
                              completion:(void (^)(NSArray<NSString *> *failedTerritories, NSError * _Nullable error))completion
{
    // 格式化日期
    // Apple API: startDate 为 nil 时表示立即生效，不应默认使用今天的日期
    NSString *startDateStr = nil;
    if (startDate)
    {
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"yyyy-MM-dd";
        fmt.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        startDateStr = [fmt stringFromDate:startDate];
    }
    
    NSLog(@"[DIYCPMgr] Updating subscription prices for %@, %lu territories, startDate=%@",
          subscriptionId, (unsigned long)pricePoints.count, startDateStr ?: @"(immediate)");
    
    // 订阅价格需要逐个地区提交（Apple API 限制）
    
    self.successTerritoriesForSub = @[].mutableCopy;
    self.failedTerritoriesForSub = @[].mutableCopy;
    
    // 递归函数，逐个提交
    [self submitSubscriptionPriceAtIndex:0
                             pricePoints:pricePoints
                          subscriptionId:subscriptionId
                            startDateStr:startDateStr
                    preserveCurrentPrice:preserveCurrentPrice
                                   total:pricePoints.count
                           progressBlock:progressBlock
                              completion:completion];
}

- (void)submitSubscriptionPriceAtIndex:(NSInteger)index
                           pricePoints:(NSArray<DIYCPPricePoint *> *)pricePoints
                        subscriptionId:(NSString *)subscriptionId
                          startDateStr:(NSString *)startDateStr
                  preserveCurrentPrice:(BOOL)preserveCurrentPrice
                                 total:(NSInteger)total
                         progressBlock:(void (^)(NSInteger completed, NSInteger total))progressBlock
                            completion:(void (^)(NSArray<NSString *> *failedTerritories, NSError * _Nullable error))completion
{
    if (index >= (NSInteger)pricePoints.count)
    {
        // 全部完成
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion([self.failedTerritoriesForSub copy], nil);
        });
        return;
    }
    
    DIYCPPricePoint *pp = pricePoints[index];
    NSString *terId = pp.territory.territoryId ?: @"";
    
    // Build attributes: preserveCurrentPrice is required; startDate is optional (null = immediate)
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    attributes[@"preserveCurrentPrice"] = @(preserveCurrentPrice);
    if (startDateStr)
    {
        attributes[@"startDate"] = startDateStr;
    }
    // else: omit startDate entirely → Apple treats as immediate
    
    // Build relationships (territory is deprecated per Apple docs, subscriptionPricePoint already implies it)
    NSDictionary *body = @{
        @"data": @{
            @"type": @"subscriptionPrices",
            @"attributes": [attributes copy],
            @"relationships": @{
                @"subscription": @{
                    @"data": @{
                        @"type": @"subscriptions",
                        @"id": subscriptionId,
                    }
                },
                @"subscriptionPricePoint": @{
                    @"data": @{
                        @"type": @"subscriptionPricePoints",
                        @"id": pp.pricePointId,
                    }
                },
            },
        },
    };
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    
    DIY_WEAK_SELF(self);
    [self startNetTaskWithURLString:@"https://api.appstoreconnect.apple.com/v1/subscriptionPrices"
                         httpMethod:@"POST"
                       sendJsonData:jsonData
                         completion:^(NSDictionary * _Nullable json, NSError * _Nullable error) {
        DIY_STRONG_SELF(self);
        
        if (error)
        {
            NSLog(@"[DIYCPMgr] Failed to update subscription price for %@: %@", terId, error.localizedDescription);
            
            // Check if this is a startDate invalid error (HTTP 409) on the first territory
            // If so, extract Apple's required date and abort the entire process
            if (index == 0 && error.code == 409)
            {
                NSString *errDesc = error.localizedDescription ?: @"";
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"Invalid startDate=.*?must be on or after (\\d{4}-\\d{2}-\\d{2})"
                                                                                      options:0
                                                                                        error:nil];
                NSTextCheckingResult *match = [regex firstMatchInString:errDesc options:0 range:NSMakeRange(0, errDesc.length)];
                if (match && match.numberOfRanges > 1)
                {
                    NSString *requiredDate = [errDesc substringWithRange:[match rangeAtIndex:1]];
                    NSLog(@"[DIYCPMgr] Apple requires startDate on or after %@, aborting subscription price update.", requiredDate);
                    
                    NSError *dateError = [NSError errorWithDomain:@"DIYCPMgr"
                                                             code:40900
                                                         userInfo:@{
                        NSLocalizedDescriptionKey: requiredDate,
                        @"DIYInvalidStartDate": requiredDate
                    }];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (completion) completion(@[], dateError);
                    });
                    return;
                }
            }
            
            @synchronized (self.failedTerritoriesForSub)
            {
                [self.failedTerritoriesForSub addObject:terId];
            }
        }
        else
        {
            NSLog(@"[DIYCPMgr] Successfully updated subscription price for %@", terId);
            [self.successTerritoriesForSub addObject:terId];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (progressBlock) progressBlock(self.successTerritoriesForSub.count, total);
        });
        
        // 延迟 0.2 秒后提交下一个，避免 API 限流
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self submitSubscriptionPriceAtIndex:index + 1
                                     pricePoints:pricePoints
                                  subscriptionId:subscriptionId
                                    startDateStr:startDateStr
                            preserveCurrentPrice:preserveCurrentPrice
                                           total:total
                                   progressBlock:progressBlock
                                      completion:completion];
        });
    }];
}

#pragma mark - App Icon (iTunes Lookup API)

- (void)fetchIconURLsForApps:(NSArray<DIYCPApp *> *)apps completion:(void (^)(NSArray<DIYCPApp *> *appsWithIcons))completion
{
    if (apps.count == 0)
    {
        if (completion)
        {
            completion(apps);
        }
        return;
    }
    
    dispatch_group_t group = dispatch_group_create();
    
    for (DIYCPApp *app in apps)
    {
        if (app.bundleId.length == 0)
        {
            continue;
        }
        
        dispatch_group_enter(group);
        
        NSString *urlString = [NSString stringWithFormat:@"https://itunes.apple.com/lookup?bundleId=%@", app.bundleId];
        NSURL *url = [NSURL URLWithString:urlString];
        
        NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (!error && data)
            {
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                NSArray *results = json[@"results"];
                if ([results isKindOfClass:[NSArray class]] && results.count > 0)
                {
                    NSDictionary *result = results.firstObject;
                    NSString *iconURL = result[@"artworkUrl512"];
                    if (![iconURL isKindOfClass:[NSString class]] || iconURL.length == 0)
                    {
                        iconURL = result[@"artworkUrl100"];
                    }
                    if ([iconURL isKindOfClass:[NSString class]] && iconURL.length > 0)
                    {
                        app.iconURL = iconURL;
                    }
                }
            }
            dispatch_group_leave(group);
        }];
        [task resume];
    }
    
    dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (completion)
        {
            completion(apps);
        }
    });
}

#pragma mark - JWT Token (via CupertinoJWT)

- (void)invalidateToken
{
    self.cachedToken = nil;
    self.tokenExpireTime = 0;
}

- (NSString *)generateJWTToken
{
    // 如果缓存的 token 还有效（提前60秒刷新），直接返回
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (self.cachedToken && now < self.tokenExpireTime - 60)
    {
        return self.cachedToken;
    }
    
    // 从用户配置读取凭据
    NSString *keyID = DIYSettings.apiKeyID;
    NSString *issuerID = DIYSettings.apiIssuerID;
    NSString *p8Content = DIYSettings.apiP8Content;
    
    if (!keyID || !issuerID || !p8Content)
    {
        NSLog(@"[DIYCPMgr] API credentials not configured");
        return nil;
    }
    
    // 使用 CupertinoJWT（通过 Swift Wrapper）生成 JWT Token
    NSString *token = [DIYJWTHelper generateTokenWithKeyID:keyID
                                                  issuerID:issuerID
                                                 p8Content:p8Content];
    if (!token)
    {
        NSLog(@"[DIYCPMgr] Failed to generate JWT token via CupertinoJWT");
        return nil;
    }
    
    self.cachedToken = token;
    self.tokenExpireTime = now + 20 * 60;
    
    return token;
}

@end
