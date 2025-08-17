#import "AlertManager.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

@interface AlertMaskView : UIView <UIGestureRecognizerDelegate>
@property (nonatomic, copy) void (^onTap)(void);
// 当触摸在该视图或其子视图上时，遮罩手势不响应（用于阻止点击内容区域触发遮罩关闭）
@property (nonatomic, weak) UIView *excludeView;
@end
@implementation AlertMaskView
 - (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.4];
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(maskTapped)];
        tap.delegate = self;
        [self addGestureRecognizer:tap];
    }
    return self;
}

- (void)maskTapped {
    if (self.onTap) self.onTap();
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    // 如果 touch 在排除视图或其子视图上，则不要让遮罩手势响应
    if (!self.excludeView) return YES;
    UIView *touchedView = touch.view;
    while (touchedView && touchedView != self) {
        if (touchedView == self.excludeView) return NO;
        touchedView = touchedView.superview;
    }
    return YES;
}

@end

@interface AlertWindow : UIWindow
@end
@implementation AlertWindow
@end

@interface AlertManager ()
@property (nonatomic, strong) AlertWindow *alertWindow;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, assign) BOOL isVisible;
@property (nonatomic, strong) UIWindow *previousKeyWindow;
@property (nonatomic, strong) CAEmitterLayer *confettiEmitter;
// 新增：保留 confetti overlay window 以避免被提前释放
@property (nonatomic, strong) AlertWindow *confettiWindow;
@property (nonatomic, strong) AlertMaskView *maskView;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, assign) AlertAnimationStyle currentStyle;
@end

@implementation AlertManager

// 全局遮罩配置
static AlertMaskStyle g_maskStyle = AlertMaskStyleDefault;
static UIColor *g_maskColor = nil; // 当 style 是 Default 或 Transparent 可使用自定义颜色
static BOOL g_maskTapToDismiss = YES;

// 新增：动画方向与物理配置
static AlertAnimationDirection g_defaultAnimationDirection = AlertAnimationDirectionAuto;
static CGFloat g_physicsGravityMagnitude = 140.0; // 与原有 yAcceleration 级别相近
static CGFloat g_physicsElasticity = 0.6; // 弹性碰撞强度（用于弹簧动画参数参考）
static NSTimeInterval g_entranceStagger = 0.03;
static NSTimeInterval g_exitStagger = 0.03;

+ (void)setMaskStyle:(AlertMaskStyle)style {
    g_maskStyle = style;
}

+ (void)setMaskColor:(UIColor *)color {
    g_maskColor = color;
}

+ (void)setMaskTapToDismiss:(BOOL)enabled {
    g_maskTapToDismiss = enabled;
}

// 新增 setter 实现
+ (void)setDefaultAnimationDirection:(AlertAnimationDirection)direction {
    g_defaultAnimationDirection = direction;
}

+ (void)setPhysicsGravityMagnitude:(CGFloat)gravity {
    if (gravity <= 0) return;
    g_physicsGravityMagnitude = gravity;
}

+ (void)setPhysicsElasticity:(CGFloat)elasticity {
    if (elasticity < 0.0) elasticity = 0.0;
    if (elasticity > 1.0) elasticity = 1.0;
    g_physicsElasticity = elasticity;
}

+ (void)setEntranceStagger:(NSTimeInterval)stagger {
    if (stagger < 0) stagger = 0;
    g_entranceStagger = stagger;
}

+ (void)setExitStagger:(NSTimeInterval)stagger {
    if (stagger < 0) stagger = 0;
    g_exitStagger = stagger;
}


+ (instancetype)sharedInstance {
    static AlertManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AlertManager alloc] init];
    });
    return instance;
}

- (AlertWindow *)alertWindow {
    if (!_alertWindow) {
        if (@available(iOS 13.0, *)) {
            // 尝试使用前台激活的 UIWindowScene
            UIWindowScene *scene = nil;
            NSSet<UIScene *> *scenes = [UIApplication sharedApplication].connectedScenes;
            for (UIScene *s in scenes) {
                if (s.activationState == UISceneActivationStateForegroundActive && [s isKindOfClass:[UIWindowScene class]]) {
                    scene = (UIWindowScene *)s;
                    break;
                }
            }
            if (scene) {
                _alertWindow = [[AlertWindow alloc] initWithWindowScene:scene];
                _alertWindow.frame = scene.coordinateSpace.bounds;
            }
        }
        if (!_alertWindow) {
            _alertWindow = [[AlertWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        }
        _alertWindow.windowLevel = UIWindowLevelAlert + 1000;
        _alertWindow.backgroundColor = [UIColor clearColor];
        _alertWindow.hidden = YES;
    }
    return _alertWindow;
}

+ (BOOL)isAlertVisible {
    return [AlertManager sharedInstance].isVisible;
}

+ (void)showWithContentView:(UIView *)contentView animated:(BOOL)animated {
    // 兼容旧 API，使用默认缩放动画
    [self showWithContentView:contentView animated:animated style:AlertAnimationStyleScale];
}

+ (void)showWithContentView:(UIView *)contentView animated:(BOOL)animated style:(AlertAnimationStyle)style {
    AlertManager *manager = [AlertManager sharedInstance];
    if (manager.isVisible) return; // 防重
    manager.isVisible = YES;
    manager.contentView = contentView;

    // 保存当前 keyWindow，以便 dismiss 时恢复（使用 windows.firstObject 兼容 iOS13+）
    if (@available(iOS 13.0, *)) {
        manager.previousKeyWindow = [UIApplication sharedApplication].windows.firstObject;
    } else {
        manager.previousKeyWindow = [UIApplication sharedApplication].keyWindow;
    }

    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    AlertMaskView *mask = [[AlertMaskView alloc] initWithFrame:CGRectMake(0, 0, screenSize.width, screenSize.height)];
    if (g_maskTapToDismiss) {
        mask.onTap = ^{ [AlertManager dismissAnimated:YES]; };
    } else {
        mask.onTap = nil;
    }

    // 根据全局遮罩风格创建背景（支持半透明、自定义颜色、透明或毛玻璃）
    UIView *maskBackgroundView = nil;
    if (g_maskStyle == AlertMaskStyleBlur) {
        if (@available(iOS 8.0, *)) {
            UIBlurEffect *be = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
            UIVisualEffectView *ev = [[UIVisualEffectView alloc] initWithEffect:be];
            ev.frame = mask.bounds;
            ev.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [mask addSubview:ev];
            maskBackgroundView = ev;
        } else {
            mask.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.34];
        }
    } else if (g_maskStyle == AlertMaskStyleTransparent) {
        mask.backgroundColor = [UIColor clearColor];
    } else {
        UIColor *c = g_maskColor ?: [[UIColor blackColor] colorWithAlphaComponent:0.4];
        mask.backgroundColor = c;
    }
    if (maskBackgroundView) {
        objc_setAssociatedObject(mask, @"_maskBackgroundView", maskBackgroundView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    // 使用 container 包裹 contentView，便于对 snapshot 动画做处理并作为 excludeView
    UIView *container = [[UIView alloc] initWithFrame:contentView.frame];
    container.backgroundColor = [UIColor clearColor];
    // 将 contentView 的坐标系调整为 container
    contentView.frame = container.bounds;
    [container addSubview:contentView];
    // 将 container 加入 mask，并居中
    [mask addSubview:container];
    container.center = CGPointMake(CGRectGetMidX(mask.bounds), CGRectGetMidY(mask.bounds));
    // 设置排除视图为 container，避免动画时遮罩响应
    mask.excludeView = container;

    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor clearColor];
    [vc.view addSubview:mask];
    manager.alertWindow.rootViewController = vc;
    manager.alertWindow.hidden = NO;
    [manager.alertWindow makeKeyAndVisible];
    // 保存引用以便 dismiss 时使用
    manager.maskView = mask;
    manager.containerView = container;
    manager.currentStyle = style;

    // 根据 style 执行动画
    switch (style) {
        case AlertAnimationStyleScale: {
            if (animated) {
                mask.alpha = 0.0;
                container.transform = CGAffineTransformMakeScale(0.8, 0.8);
                container.alpha = 0.0;
                [UIView animateWithDuration:0.25 animations:^{
                    mask.alpha = 1.0;
                    container.transform = CGAffineTransformIdentity;
                    container.alpha = 1.0;
                }];
            } else {
                mask.alpha = 1.0;
            }
        } break;
        case AlertAnimationStyleSpring: {
            mask.alpha = 0.0;
            container.transform = CGAffineTransformMakeScale(0.6, 0.6);
            container.alpha = 0.0;
            [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:1 options:UIViewAnimationOptionCurveEaseOut animations:^{
                mask.alpha = 1.0;
                container.transform = CGAffineTransformIdentity;
                container.alpha = 1.0;
            } completion:nil];
        } break;
        case AlertAnimationStyleDoor: {
            // Door: 支持左右/上下/前后方向的门效果
            CGFloat w = container.bounds.size.width;
            CGFloat h = container.bounds.size.height;
            BOOL vertical = (g_defaultAnimationDirection == AlertAnimationDirectionTop || g_defaultAnimationDirection == AlertAnimationDirectionBottom);
            UIView *firstSnap;
            UIView *secondSnap;
            CGRect firstRect, secondRect;
            if (vertical) {
                firstRect = CGRectMake(0, 0, w, h/2.0);
                secondRect = CGRectMake(0, h/2.0, w, h - h/2.0);
            } else {
                firstRect = CGRectMake(0, 0, w/2.0, h);
                secondRect = CGRectMake(w/2.0, 0, w - w/2.0, h);
            }
            firstSnap = [container resizableSnapshotViewFromRect:firstRect afterScreenUpdates:YES withCapInsets:UIEdgeInsetsZero];
            secondSnap = [container resizableSnapshotViewFromRect:secondRect afterScreenUpdates:YES withCapInsets:UIEdgeInsetsZero];
            if (vertical) {
                firstSnap.frame = CGRectMake(container.center.x - w/2.0, container.center.y - h/2.0, w, h/2.0);
                secondSnap.frame = CGRectMake(container.center.x - w/2.0, container.center.y, w, h - h/2.0);
            } else {
                firstSnap.frame = CGRectMake(container.center.x - w/2.0, container.center.y - h/2.0, firstRect.size.width, h);
                secondSnap.frame = CGRectMake(container.center.x, container.center.y - h/2.0, secondRect.size.width, h);
            }
            container.hidden = YES;
            [mask addSubview:firstSnap];
            [mask addSubview:secondSnap];
            // 设置锚点与位置
            CATransform3D perspective = CATransform3DIdentity; perspective.m34 = -1.0/1000.0;
            if (vertical) {
                firstSnap.layer.anchorPoint = CGPointMake(0.5, 1.0);
                secondSnap.layer.anchorPoint = CGPointMake(0.5, 0.0);
                firstSnap.layer.position = CGPointMake(CGRectGetMidX(firstSnap.frame), CGRectGetMaxY(firstSnap.frame));
                secondSnap.layer.position = CGPointMake(CGRectGetMidX(secondSnap.frame), CGRectGetMinY(secondSnap.frame));
                firstSnap.layer.transform = CATransform3DRotate(perspective, M_PI_2, 1, 0, 0);
                secondSnap.layer.transform = CATransform3DRotate(perspective, -M_PI_2, 1, 0, 0);
            } else {
                firstSnap.layer.anchorPoint = CGPointMake(1.0, 0.5);
                secondSnap.layer.anchorPoint = CGPointMake(0.0, 0.5);
                firstSnap.layer.position = CGPointMake(CGRectGetMaxX(firstSnap.frame), CGRectGetMidY(firstSnap.frame));
                secondSnap.layer.position = CGPointMake(CGRectGetMinX(secondSnap.frame), CGRectGetMidY(secondSnap.frame));
                firstSnap.layer.transform = CATransform3DRotate(perspective, M_PI_2, 0, 1, 0);
                secondSnap.layer.transform = CATransform3DRotate(perspective, -M_PI_2, 0, 1, 0);
            }
            mask.alpha = 1.0;
            [UIView animateWithDuration:0.5 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                firstSnap.layer.transform = CATransform3DIdentity;
                secondSnap.layer.transform = CATransform3DIdentity;
            } completion:^(BOOL finished) {
                [firstSnap removeFromSuperview];
                [secondSnap removeFromSuperview];
                container.hidden = NO;
            }];
        } break;
        case AlertAnimationStyleExplode: {
            // 改进：入场为碎片从四周聚合成完整内容（视觉更好），出场将在 dismiss 时做碎片散开
            CGFloat w = container.bounds.size.width;
            CGFloat h = container.bounds.size.height;
            // 使用更少的碎片以提升视觉效果
            NSInteger rows = 4;
            NSInteger cols = 4;
            CGFloat pieceW = w / cols;
            CGFloat pieceH = h / rows;
            // pieces 存储字典 { @"view": UIView, @"target": NSValue(CGRect) }
            NSMutableArray<NSDictionary *> *pieces = [NSMutableArray array];
            // 生成碎片快照并放置在随机外部位置
            // 生成碎片并根据方向对其入场顺序进行排序
            NSMutableArray<NSDictionary *> *rawPieces = [NSMutableArray array];
            for (NSInteger r = 0; r < rows; r++) {
                for (NSInteger c = 0; c < cols; c++) {
                    CGRect pieceRect = CGRectMake(c * pieceW, r * pieceH, pieceW, pieceH);
                    UIView *snap = [container resizableSnapshotViewFromRect:pieceRect afterScreenUpdates:YES withCapInsets:UIEdgeInsetsZero];
                    CGRect targetFrame = CGRectMake(container.frame.origin.x + pieceRect.origin.x, container.frame.origin.y + pieceRect.origin.y, pieceRect.size.width, pieceRect.size.height);
                    // 起始点根据方向优先从相对一侧外部进入
                    CGFloat startX = 0, startY = 0;
                    CGFloat extra = 60 + arc4random_uniform(140);
                    // 默认从四周随机进入，若有默认方向则从对应方向外部进入
                    AlertAnimationDirection dir = g_defaultAnimationDirection;
                    if (dir == AlertAnimationDirectionAuto) dir = AlertAnimationDirectionBottom;
                    switch (dir) {
                        case AlertAnimationDirectionTop:
                            startX = container.frame.origin.x + pieceRect.origin.x + (arc4random_uniform(60) - 30);
                            startY = -extra;
                            break;
                        case AlertAnimationDirectionBottom:
                            startX = container.frame.origin.x + pieceRect.origin.x + (arc4random_uniform(60) - 30);
                            startY = screenSize.height + extra;
                            break;
                        case AlertAnimationDirectionLeft:
                            startX = -extra;
                            startY = container.frame.origin.y + pieceRect.origin.y + (arc4random_uniform(60) - 30);
                            break;
                        case AlertAnimationDirectionRight:
                            startX = screenSize.width + extra;
                            startY = container.frame.origin.y + pieceRect.origin.y + (arc4random_uniform(60) - 30);
                            break;
                        default:
                            // random
                            {
                                int edge = arc4random_uniform(4);
                                switch (edge) {
                                    case 0: startX = (CGFloat)arc4random_uniform((uint32_t)screenSize.width); startY = -extra; break;
                                    case 1: startX = (CGFloat)arc4random_uniform((uint32_t)screenSize.width); startY = screenSize.height + extra; break;
                                    case 2: startX = -extra; startY = (CGFloat)arc4random_uniform((uint32_t)screenSize.height); break;
                                    default: startX = screenSize.width + extra; startY = (CGFloat)arc4random_uniform((uint32_t)screenSize.height); break;
                                }
                            }
                            break;
                    }
                    snap.frame = CGRectMake(startX, startY, pieceRect.size.width, pieceRect.size.height);
                    snap.alpha = 0.0;
                    [mask addSubview:snap];
                    snap.layer.opacity = 0.0;
                    [rawPieces addObject:@{@"view": snap, @"target": [NSValue valueWithCGRect:targetFrame], @"row": @(r), @"col": @(c)}];
                }
            }
            // 根据方向对 rawPieces 排序，确保从指定方向逐步进入
            NSArray *sorted = [rawPieces sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                NSInteger ra = [a[@"row"] integerValue]; NSInteger ca = [a[@"col"] integerValue];
                NSInteger rb = [b[@"row"] integerValue]; NSInteger cb = [b[@"col"] integerValue];
                switch (g_defaultAnimationDirection) {
                    case AlertAnimationDirectionTop: return (ra < rb) ? NSOrderedAscending : (ra > rb) ? NSOrderedDescending : NSOrderedSame;
                    case AlertAnimationDirectionBottom: return (ra > rb) ? NSOrderedAscending : (ra < rb) ? NSOrderedDescending : NSOrderedSame;
                    case AlertAnimationDirectionLeft: return (ca < cb) ? NSOrderedAscending : (ca > cb) ? NSOrderedDescending : NSOrderedSame;
                    case AlertAnimationDirectionRight: return (ca > cb) ? NSOrderedAscending : (ca < cb) ? NSOrderedDescending : NSOrderedSame;
                    default: return NSOrderedSame;
                }
            }];
            // 将排序后的 pieces 填充到 pieces 数组
            for (NSDictionary *d in sorted) { [pieces addObject:d]; }
            // 隐藏 container，使用分片错开延迟聚合动画
            container.hidden = YES;
            mask.alpha = 1.0;
            __block NSTimeInterval delay = 0;
            for (NSDictionary *dict in pieces) {
                UIView *p = dict[@"view"];
                CGRect tf = [dict[@"target"] CGRectValue];
                p.transform = CGAffineTransformMakeScale(0.9, 0.9);
                [UIView animateWithDuration:0.48 delay:delay options:UIViewAnimationOptionCurveEaseOut animations:^{
                    p.frame = tf;
                    p.alpha = 1.0;
                    p.transform = CGAffineTransformIdentity;
                } completion:nil];
                delay += g_entranceStagger;
            }
            // 在最后一个动画完成后清理并显示 container
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((0.48 + delay) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                for (NSDictionary *dict in pieces) {
                    UIView *p = dict[@"view"];
                    [p removeFromSuperview];
                }
                container.hidden = NO;
                container.alpha = 0.0;
                container.transform = CGAffineTransformMakeScale(0.95, 0.95);
                [UIView animateWithDuration:0.2 animations:^{
                    container.alpha = 1.0;
                    container.transform = CGAffineTransformIdentity;
                }];
            });
        } break;
        
        case AlertAnimationStyleGravity: {
            // 重力下落效果：支持从不同方向入场并使用全局重力/弹性参数
            mask.alpha = 1.0;
            CGPoint startCenter = CGPointMake(CGRectGetMidX(mask.bounds), CGRectGetMidY(mask.bounds));
            switch (g_defaultAnimationDirection) {
                case AlertAnimationDirectionLeft: startCenter = CGPointMake(-container.bounds.size.width, CGRectGetMidY(mask.bounds)); break;
                case AlertAnimationDirectionRight: startCenter = CGPointMake(CGRectGetMaxX(mask.bounds) + container.bounds.size.width, CGRectGetMidY(mask.bounds)); break;
                case AlertAnimationDirectionTop: startCenter = CGPointMake(CGRectGetMidX(mask.bounds), -container.bounds.size.height); break;
                case AlertAnimationDirectionBottom: startCenter = CGPointMake(CGRectGetMidX(mask.bounds), CGRectGetMaxY(mask.bounds) + container.bounds.size.height); break;
                default: startCenter = CGPointMake(CGRectGetMidX(mask.bounds), -container.bounds.size.height); break;
            }
            container.center = startCenter;
            container.alpha = 1.0;
            // 使用弹簧动画，damping 受 g_physicsElasticity 影响（越大越不弹）
            CGFloat damping = MAX(0.2, 1.0 - g_physicsElasticity);
            CGFloat velocity = 0.8;
            [UIView animateWithDuration:0.6 delay:0 usingSpringWithDamping:damping initialSpringVelocity:velocity options:UIViewAnimationOptionCurveEaseIn animations:^{
                container.center = CGPointMake(CGRectGetMidX(mask.bounds), CGRectGetMidY(mask.bounds));
            } completion:nil];
        } break;
        case AlertAnimationStyleSesame: {
            // 芝麻开门：支持左右/上下铰链门，节奏稍微快一点
            mask.alpha = 1.0;
            CGFloat w = container.bounds.size.width;
            CGFloat h = container.bounds.size.height;
            BOOL vertical = (g_defaultAnimationDirection == AlertAnimationDirectionTop || g_defaultAnimationDirection == AlertAnimationDirectionBottom);
            UIView *first = nil; UIView *second = nil; CGRect r1, r2;
            if (vertical) {
                r1 = CGRectMake(0, 0, w, h/2.0);
                r2 = CGRectMake(0, h/2.0, w, h - h/2.0);
            } else {
                r1 = CGRectMake(0, 0, w/2.0, h);
                r2 = CGRectMake(w/2.0, 0, w - w/2.0, h);
            }
            first = [container resizableSnapshotViewFromRect:r1 afterScreenUpdates:YES withCapInsets:UIEdgeInsetsZero];
            second = [container resizableSnapshotViewFromRect:r2 afterScreenUpdates:YES withCapInsets:UIEdgeInsetsZero];
            if (vertical) {
                first.frame = CGRectMake(container.center.x - w/2.0, container.center.y - h/2.0, w, h/2.0);
                second.frame = CGRectMake(container.center.x - w/2.0, container.center.y, w, h - h/2.0);
                first.layer.anchorPoint = CGPointMake(0.5, 1.0);
                second.layer.anchorPoint = CGPointMake(0.5, 0.0);
                first.layer.position = CGPointMake(CGRectGetMidX(first.frame), CGRectGetMaxY(first.frame));
                second.layer.position = CGPointMake(CGRectGetMidX(second.frame), CGRectGetMinY(second.frame));
                CATransform3D perspective = CATransform3DIdentity; perspective.m34 = -1.0/900.0;
                first.layer.transform = CATransform3DRotate(perspective, M_PI_2, 1, 0, 0);
                second.layer.transform = CATransform3DRotate(perspective, -M_PI_2, 1, 0, 0);
            } else {
                first.frame = CGRectMake(container.center.x - w/2.0, container.center.y - h/2.0, r1.size.width, h);
                second.frame = CGRectMake(container.center.x, container.center.y - h/2.0, r2.size.width, h);
                first.layer.anchorPoint = CGPointMake(1.0, 0.5);
                second.layer.anchorPoint = CGPointMake(0.0, 0.5);
                first.layer.position = CGPointMake(CGRectGetMidX(first.frame), CGRectGetMidY(first.frame));
                second.layer.position = CGPointMake(CGRectGetMidX(second.frame), CGRectGetMidY(second.frame));
                CATransform3D perspective = CATransform3DIdentity; perspective.m34 = -1.0/900.0;
                first.layer.transform = CATransform3DRotate(perspective, M_PI_2, 0, 1, 0);
                second.layer.transform = CATransform3DRotate(perspective, -M_PI_2, 0, 1, 0);
            }
            container.hidden = YES;
            [mask addSubview:first]; [mask addSubview:second];
            // 略微错开时间
            [UIView animateWithDuration:0.44 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                first.layer.transform = CATransform3DIdentity;
            } completion:nil];
            [UIView animateWithDuration:0.44 delay:0.06 options:UIViewAnimationOptionCurveEaseOut animations:^{
                second.layer.transform = CATransform3DIdentity;
            } completion:^(BOOL finished) {
                [first removeFromSuperview]; [second removeFromSuperview]; container.hidden = NO;
            }];
        } break;
        case AlertAnimationStyleElastic: {
            // 弹性碰撞：从中心快速放大然后反弹稳定，damping 受 g_physicsElasticity 控制
            mask.alpha = 1.0;
            container.transform = CGAffineTransformMakeScale(0.2, 0.2);
            container.alpha = 0.0;
            CGFloat damping = MAX(0.2, 1.0 - g_physicsElasticity);
            CGFloat velocity = 4.0;
            [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:damping initialSpringVelocity:velocity options:UIViewAnimationOptionCurveEaseOut animations:^{
                container.transform = CGAffineTransformIdentity;
                container.alpha = 1.0;
            } completion:nil];
        } break;
        case AlertAnimationStyleConfetti: {
            // Confetti: classic burst -> slow fall (mixed ribbons + dots)
            mask.alpha = 1.0;
            container.alpha = 0.0;
            container.transform = CGAffineTransformMakeScale(0.92, 0.92);
            [UIView animateWithDuration:0.34 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:1 options:0 animations:^{
                container.alpha = 1.0;
                container.transform = CGAffineTransformIdentity;
            } completion:^(BOOL finished) {
                CGPoint topPoint = CGPointMake(CGRectGetMidX(mask.bounds), MAX(36.0, CGRectGetMinY(mask.bounds) + 36.0));

                CAEmitterLayer *burst = [CAEmitterLayer layer];
                burst.emitterPosition = topPoint;
                burst.emitterShape = kCAEmitterLayerSphere;
                burst.emitterSize = CGSizeMake(10, 10);

                // Classic bright palette
                NSArray *colors = @[[UIColor colorWithRed:0.95 green:0.24 blue:0.21 alpha:1.0], // red
                                    [UIColor colorWithRed:0.14 green:0.57 blue:0.95 alpha:1.0], // blue
                                    [UIColor colorWithRed:1.00 green:0.84 blue:0.19 alpha:1.0], // yellow
                                    [UIColor colorWithRed:0.20 green:0.80 blue:0.40 alpha:1.0], // green
                                    [UIColor colorWithRed:0.78 green:0.36 blue:0.96 alpha:1.0]]; // purple

                NSMutableArray *cells = [NSMutableArray array];

                // Ribbons / small rectangles (visually dominant)
                for (UIColor *color in colors) {
                    CAEmitterCell *ribbon = [CAEmitterCell emitterCell];
                    ribbon.birthRate = 600; // strong instantaneous burst
                    ribbon.lifetime = 4.0 + (arc4random_uniform(30) / 10.0); // 4.0 - 7.0s
                    ribbon.velocity = 260 + arc4random_uniform(120);
                    ribbon.velocityRange = 80;
                    ribbon.emissionRange = M_PI * 2.0;
                    ribbon.yAcceleration = 140 + arc4random_uniform(60);
                    ribbon.xAcceleration = (arc4random_uniform(40) - 20);
                    ribbon.spin = ((arc4random_uniform(400) / 100.0) - 2.0);
                    ribbon.spinRange = 4.0;
                    ribbon.scale = 0.16 + (arc4random_uniform(6) / 100.0);
                    ribbon.scaleRange = 0.16;
                    ribbon.alphaSpeed = -0.15 / ribbon.lifetime; // fade over lifetime

                    CGSize imgSize = CGSizeMake(4 + arc4random_uniform(6), 20 + arc4random_uniform(12));
                    UIGraphicsBeginImageContextWithOptions(imgSize, NO, 0);
                    CGContextRef ctx = UIGraphicsGetCurrentContext();
                    CGContextClearRect(ctx, CGRectMake(0, 0, imgSize.width, imgSize.height));
                    UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, imgSize.width, imgSize.height) cornerRadius:imgSize.width/2.0];
                    CGContextSetFillColorWithColor(ctx, color.CGColor);
                    [p fill];
                    UIImage *rimg = UIGraphicsGetImageFromCurrentImageContext();
                    UIGraphicsEndImageContext();
                    ribbon.contents = (__bridge id)rimg.CGImage;
                    [cells addObject:ribbon];
                }

                // Small round confetti / glitter
                for (UIColor *color in colors) {
                    CAEmitterCell *dot = [CAEmitterCell emitterCell];
                    dot.birthRate = 200;
                    dot.lifetime = 3.0 + (arc4random_uniform(20) / 10.0); // 3.0 - 5.0s
                    dot.velocity = 180 + arc4random_uniform(140);
                    dot.velocityRange = 60;
                    dot.emissionRange = M_PI * 2.0;
                    dot.yAcceleration = 160;
                    dot.xAcceleration = (arc4random_uniform(40) - 20);
                    dot.spin = ((arc4random_uniform(300) / 100.0) - 1.5);
                    dot.spinRange = 3.0;
                    dot.scale = 0.14 + (arc4random_uniform(6) / 100.0);
                    dot.scaleRange = 0.14;
                    dot.alphaSpeed = -0.25 / dot.lifetime;

                    CGSize dotSize = CGSizeMake(4 + arc4random_uniform(6), 4 + arc4random_uniform(6));
                    UIGraphicsBeginImageContextWithOptions(dotSize, NO, 0);
                    CGContextRef dctx = UIGraphicsGetCurrentContext();
                    CGContextClearRect(dctx, CGRectMake(0, 0, dotSize.width, dotSize.height));
                    UIBezierPath *c = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, dotSize.width, dotSize.height)];
                    CGContextSetFillColorWithColor(dctx, color.CGColor);
                    [c fill];
                    UIImage *dimg = UIGraphicsGetImageFromCurrentImageContext();
                    UIGraphicsEndImageContext();
                    dot.contents = (__bridge id)dimg.CGImage;
                    [cells addObject:dot];
                }

                burst.emitterCells = cells;

                // overlay window
                AlertWindow *confettiWindow = nil;
                if (@available(iOS 13.0, *)) {
                    UIWindowScene *scene = nil;
                    NSSet<UIScene *> *scenes = [UIApplication sharedApplication].connectedScenes;
                    for (UIScene *s in scenes) {
                        if (s.activationState == UISceneActivationStateForegroundActive && [s isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene *)s; break; }
                    }
                    if (scene) confettiWindow = [[AlertWindow alloc] initWithWindowScene:scene];
                }
                if (!confettiWindow) confettiWindow = [[AlertWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
                confettiWindow.windowLevel = UIWindowLevelAlert + 2000;
                confettiWindow.backgroundColor = [UIColor clearColor];
                UIViewController *cwvc = [[UIViewController alloc] init];
                cwvc.view.backgroundColor = [UIColor clearColor];
                confettiWindow.rootViewController = cwvc;
                confettiWindow.userInteractionEnabled = NO;
                confettiWindow.hidden = NO;

                [confettiWindow.rootViewController.view.layer addSublayer:burst];
                manager.confettiEmitter = burst;
                manager.confettiWindow = confettiWindow;

                // 保留原有 alert 窗口和内容，Confetti 仅为视觉效果，不自动 dismiss 弹窗。
                // 弹窗的隐藏/清理应由调用方或用户交互时触发 dismissAnimated: 处理。

                // Short instantaneous burst then stop emitting
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    burst.birthRate = 0;
                });

                // Remove overlay after particles settle
                NSTimeInterval totalVisible = 6.5;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(totalVisible * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [UIView animateWithDuration:0.9 animations:^{ confettiWindow.alpha = 0.0; } completion:^(BOOL finished) {
                        [burst removeFromSuperlayer];
                        if (manager.confettiEmitter == burst) manager.confettiEmitter = nil;
                        if (manager.confettiWindow == confettiWindow) {
                            manager.confettiWindow.hidden = YES;
                            manager.confettiWindow.rootViewController = nil;
                            manager.confettiWindow = nil;
                        }
                    }];
                });
            }];
        } break;
    }
}

+ (void)dismissAnimated:(BOOL)animated {
    AlertManager *manager = [AlertManager sharedInstance];
    if (!manager.isVisible) return;
    manager.isVisible = NO;
    UIView *contentView = manager.contentView;
    void (^finalCleanup)(void) = ^{
        // 隐藏并清理
        if (manager.confettiEmitter) {
            [manager.confettiEmitter removeFromSuperlayer];
            manager.confettiEmitter = nil;
        }
        if (manager.confettiWindow) {
            manager.confettiWindow.hidden = YES;
            manager.confettiWindow.rootViewController = nil;
            manager.confettiWindow = nil;
        }
        manager.alertWindow.hidden = YES;
        manager.alertWindow.rootViewController = nil;
        manager.contentView = nil;
        manager.maskView = nil;
        manager.containerView = nil;
        // 恢复之前的 keyWindow（如果存在）
        if (manager.previousKeyWindow) {
            [manager.previousKeyWindow makeKeyWindow];
            manager.previousKeyWindow = nil;
        }
    };

    // 根据当前动画风格执行相应的出场动画
    switch (manager.currentStyle) {
        case AlertAnimationStyleExplode: {
            // 碎片化出场：将 container 分割为碎片并向外飞散
            UIView *container = manager.containerView ?: manager.contentView;
            CGFloat w = container.bounds.size.width;
            CGFloat h = container.bounds.size.height;
            NSInteger rows = 4;
            NSInteger cols = 4;
            CGFloat pieceW = w / cols;
            CGFloat pieceH = h / rows;
            NSMutableArray<UIView *> *pieces = [NSMutableArray array];
            for (NSInteger r = 0; r < rows; r++) {
                for (NSInteger c = 0; c < cols; c++) {
                    CGRect pieceRect = CGRectMake(c * pieceW, r * pieceH, pieceW, pieceH);
                    UIView *snap = [container resizableSnapshotViewFromRect:pieceRect afterScreenUpdates:NO withCapInsets:UIEdgeInsetsZero];
                    snap.frame = CGRectMake(container.frame.origin.x + pieceRect.origin.x, container.frame.origin.y + pieceRect.origin.y, pieceRect.size.width, pieceRect.size.height);
                    [manager.maskView addSubview:snap];
                    [pieces addObject:snap];
                }
            }
            container.hidden = YES;
            // 分片按序错开出场
            __block NSTimeInterval delay = 0;
            for (UIView *p in pieces) {
                CGFloat dx = (arc4random_uniform(600) - 300);
                CGFloat dy = (arc4random_uniform(600) - 300);
                // 根据默认方向调整主要散开方向
                switch (g_defaultAnimationDirection) {
                    case AlertAnimationDirectionLeft: dx = - (200 + arc4random_uniform(300)); break;
                    case AlertAnimationDirectionRight: dx = (200 + arc4random_uniform(300)); break;
                    case AlertAnimationDirectionTop: dy = - (200 + arc4random_uniform(300)); break;
                    case AlertAnimationDirectionBottom: dy = (200 + arc4random_uniform(300)); break;
                    default: break;
                }
                [UIView animateWithDuration:0.5 delay:delay options:UIViewAnimationOptionCurveEaseIn animations:^{
                    p.transform = CGAffineTransformTranslate(CGAffineTransformMakeRotation((arc4random_uniform(360) - 180) * M_PI / 180.0), dx, dy);
                    p.alpha = 0.0;
                } completion:^(BOOL finished) {
                    [p removeFromSuperview];
                }];
                delay += g_exitStagger;
            }
            // 在所有分片开始动画后再淡出 mask 并清理
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((0.5 + delay) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.18 animations:^{ manager.maskView.alpha = 0.0; } completion:^(BOOL finished) { finalCleanup(); }];
            });
        } break;
        case AlertAnimationStyleConfetti: {
            // 停止发射并淡出 mask + container
            if (manager.confettiEmitter) manager.confettiEmitter.birthRate = 0;
            [UIView animateWithDuration:0.35 animations:^{
                manager.maskView.alpha = 0.0;
                manager.containerView.alpha = 0.0;
            } completion:^(BOOL finished) {
                finalCleanup();
            }];
        } break;
        default: {
            if (animated && contentView) {
                [UIView animateWithDuration:0.2 animations:^{
                    contentView.transform = CGAffineTransformMakeScale(0.8, 0.8);
                    contentView.alpha = 0;
                } completion:^(BOOL finished) {
                    finalCleanup();
                }];
            } else {
                finalCleanup();
            }
        } break;
    }
}

@end
