#import <UIKit/UIKit.h>

@interface AlertManager : NSObject

typedef NS_ENUM(NSInteger, AlertAnimationStyle) {
	AlertAnimationStyleScale = 0,   // 传统缩放淡入
	AlertAnimationStyleSpring,      // 弹簧弹性效果
	AlertAnimationStyleDoor,        // 左右门打开
	AlertAnimationStyleExplode,      // 碎片化散开再重组
    AlertAnimationStyleConfetti,   // 彩带/花瓣/纸屑飞散效果
	AlertAnimationStyleGravity,    // 重力下落/惯性效果
	AlertAnimationStyleSesame,     // 芝麻开门（铰链门）
	AlertAnimationStyleElastic    // 弹性碰撞效果（弹跳/反弹）
};

typedef NS_ENUM(NSInteger, AlertMaskStyle) {
	AlertMaskStyleDefault = 0, // 默认黑色半透明 (alpha=0.4)
	AlertMaskStyleTransparent,  // 完全透明（不挡视线）
	AlertMaskStyleBlur          // 毛玻璃模糊背景
};

// 新增：动画方向/物理配置
typedef NS_ENUM(NSInteger, AlertAnimationDirection) {
	AlertAnimationDirectionAuto = 0, // 根据样式使用默认（左右/上下等）
	AlertAnimationDirectionLeft,
	AlertAnimationDirectionRight,
	AlertAnimationDirectionTop,
	AlertAnimationDirectionBottom,
	AlertAnimationDirectionFront,
	AlertAnimationDirectionBack
};

// 配置全局动画方向与物理属性（可选）
// 设置默认的动画方向（比如 Door 可从左右改为上下）
+ (void)setDefaultAnimationDirection:(AlertAnimationDirection)direction;
// 重力强度（用于 Gravity/Confetti 等，单位感知式，默认适中）
+ (void)setPhysicsGravityMagnitude:(CGFloat)gravity;
// 弹性/回弹强度，范围 0.0 - 1.0，1.0 最弹
+ (void)setPhysicsElasticity:(CGFloat)elasticity;
// 入场/出场子项错开延迟（用于碎片/门等分块按顺序动画），单位秒
+ (void)setEntranceStagger:(NSTimeInterval)stagger;
+ (void)setExitStagger:(NSTimeInterval)stagger;


// 旧 API 保留，默认使用 AlertAnimationStyleScale
+ (void)showWithContentView:(UIView *)contentView animated:(BOOL)animated;
// 新 API：可指定动画风格
+ (void)showWithContentView:(UIView *)contentView animated:(BOOL)animated style:(AlertAnimationStyle)style;

+ (void)dismissAnimated:(BOOL)animated;
+ (BOOL)isAlertVisible;

// 遮罩背景配置（可选）：设置遮罩样式或自定义遮罩颜色（仅在非 blur 模式下使用）
+ (void)setMaskStyle:(AlertMaskStyle)style;
+ (void)setMaskColor:(UIColor *)color;
// 是否点击遮罩自动关闭（默认 YES）
+ (void)setMaskTapToDismiss:(BOOL)enabled;

@end
