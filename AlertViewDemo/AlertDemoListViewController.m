#import "AlertDemoListViewController.h"
#import "AlertManager.h"
#import "AlertDemoViewController.h"

@interface AlertDemoListViewController ()
@property (nonatomic, strong) NSArray<NSString *> *demoTitles;
@end

@implementation AlertDemoListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"弹窗组件Demo";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.demoTitles = @[ @"基础弹窗 — Scale", @"带输入框弹窗 — Spring", @"防重弹窗 — Door", @"自定义动画弹窗 — Explode", @"遮罩点击关闭 — Confetti", @"多内容弹窗 — Scale", @"重力惯性 — Gravity", @"芝麻开门 — Sesame", @"弹性碰撞 — Elastic", @"遮罩示例 — 半透明", @"遮罩示例 — 透明", @"遮罩示例 — 毛玻璃", @"方向体验 — Door 左右", @"方向体验 — Door 上下", @"方向体验 — Explode 从上", @"方向体验 — Gravity 从左", @"方向体验 — Elastic 从下", @"方向体验 — Sesame 前后" ];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"cell"];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.demoTitles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    cell.backgroundColor = [UIColor systemGroupedBackgroundColor];
    cell.textLabel.text = self.demoTitles[indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSLog(@"点击了第%ld行", indexPath.row);
    switch (indexPath.row) {
        case 0: [self showBasicAlert]; break;
        case 1: [self showInputAlert]; break;
        case 2: [self showPreventRepeatAlert]; break;
        case 3: [self showCustomAnimationAlert]; break;
        case 4: [self showMaskTapCloseAlert]; break;
        case 5: [self showMultiContentAlert]; break;
        case 6: [self showGravityAlert]; break;
        case 7: [self showSesameAlert]; break;
    case 8: [self showElasticAlert]; break;
    case 9: [self showMaskDefaultAlert]; break;
    case 10: [self showMaskTransparentAlert]; break;
    case 11: [self showMaskBlurAlert]; break;
    case 12: [self showDoorLeftDemo]; break;
    case 13: [self showDoorTopDemo]; break;
    case 14: [self showExplodeTopDemo]; break;
    case 15: [self showGravityLeftDemo]; break;
    case 16: [self showElasticBottomDemo]; break;
    case 17: [self showSesameFrontDemo]; break;
        default: break;
    }
}

#pragma mark - Demo Methods

- (void)showBasicAlert {
    UIView *alertView = [self buildAlertViewWithTitle:@"基础弹窗" desc:@"这是一个最基础的弹窗。" buttonTitle:@"关闭" action:^{ [AlertManager dismissAnimated:YES]; }];
    [AlertManager showWithContentView:alertView animated:YES style:AlertAnimationStyleScale];
}

- (void)showInputAlert {
    UIView *alertView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 280, 200)];
    alertView.backgroundColor = [UIColor whiteColor];
    alertView.layer.cornerRadius = 16;
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, 280, 30)];
    label.text = @"请输入内容";
    label.textAlignment = NSTextAlignmentCenter;
    [alertView addSubview:label];
    UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(20, 60, 240, 40)];
    textField.borderStyle = UITextBorderStyleRoundedRect;
    [alertView addSubview:textField];
    UIButton *okBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    okBtn.frame = CGRectMake(90, 120, 100, 40);
    [okBtn setTitle:@"确定" forState:UIControlStateNormal];
    [okBtn addTarget:self action:@selector(closeAlert) forControlEvents:UIControlEventTouchUpInside];
    [alertView addSubview:okBtn];
    [AlertManager showWithContentView:alertView animated:YES style:AlertAnimationStyleSpring];
}

- (void)showPreventRepeatAlert {
    if ([AlertManager isAlertVisible]) {
        UIAlertController *ac = [UIAlertController alertControllerWithTitle:@"已弹出" message:@"当前已有弹窗，无法重复弹出。" preferredStyle:UIAlertControllerStyleAlert];
        [ac addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:ac animated:YES completion:nil];
        return;
    }
    UIView *alertView = [self buildAlertViewWithTitle:@"防重弹窗" desc:@"已实现防止重复弹出。" buttonTitle:@"关闭" action:^{ [AlertManager dismissAnimated:YES]; }];
    [AlertManager showWithContentView:alertView animated:YES style:AlertAnimationStyleDoor];
}

- (void)showCustomAnimationAlert {
    UIView *alertView = [self buildAlertViewWithTitle:@"自定义动画弹窗" desc:@"弹窗带缩放动画。" buttonTitle:@"关闭" action:^{ [AlertManager dismissAnimated:YES]; }];
    [AlertManager showWithContentView:alertView animated:YES style:AlertAnimationStyleExplode];
}

- (void)showMaskTapCloseAlert {
    UIView *alertView = [self buildAlertViewWithTitle:@"遮罩点击关闭" desc:@"点击弹窗外部遮罩可关闭弹窗。" buttonTitle:@"关闭" action:^{ [AlertManager dismissAnimated:YES]; }];
    [AlertManager showWithContentView:alertView animated:YES style:AlertAnimationStyleConfetti];
}

- (void)showMultiContentAlert {
    UIView *alertView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 220)];
    alertView.backgroundColor = [UIColor whiteColor];
    alertView.layer.cornerRadius = 16;
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, 300, 30)];
    label.text = @"多内容弹窗";
    label.textAlignment = NSTextAlignmentCenter;
    [alertView addSubview:label];
    UIImageView *imgView = [[UIImageView alloc] initWithFrame:CGRectMake(120, 60, 60, 60)];
    imgView.image = [UIImage systemImageNamed:@"star.fill"];
    imgView.tintColor = [UIColor systemYellowColor];
    [alertView addSubview:imgView];
    UILabel *desc = [[UILabel alloc] initWithFrame:CGRectMake(0, 130, 300, 30)];
    desc.text = @"支持图片、文字、按钮等多内容展示。";
    desc.textAlignment = NSTextAlignmentCenter;
    desc.font = [UIFont systemFontOfSize:15];
    [alertView addSubview:desc];
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(100, 170, 100, 40);
    [closeBtn setTitle:@"关闭弹窗" forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closeAlert) forControlEvents:UIControlEventTouchUpInside];
    [alertView addSubview:closeBtn];
    [AlertManager showWithContentView:alertView animated:YES style:AlertAnimationStyleScale];
}

- (void)showGravityAlert {
    UIView *alertView = [self buildAlertViewWithTitle:@"重力弹窗" desc:@"带重力惯性效果的弹窗。" buttonTitle:@"关闭" action:^{ [AlertManager dismissAnimated:YES]; }];
    [AlertManager showWithContentView:alertView animated:YES style:AlertAnimationStyleGravity];
}

- (void)showSesameAlert {
    UIView *alertView = [self buildAlertViewWithTitle:@"芝麻开门" desc:@"铰链门式打开动画。" buttonTitle:@"关闭" action:^{ [AlertManager dismissAnimated:YES]; }];
    [AlertManager showWithContentView:alertView animated:YES style:AlertAnimationStyleSesame];
}

- (void)showElasticAlert {
    UIView *alertView = [self buildAlertViewWithTitle:@"弹性碰撞" desc:@"带弹性反弹的入场效果。" buttonTitle:@"关闭" action:^{ [AlertManager dismissAnimated:YES]; }];
    [AlertManager showWithContentView:alertView animated:YES style:AlertAnimationStyleElastic];
}

- (void)showMaskDefaultAlert {
    UIView *alertView = [self buildAlertViewWithTitle:@"半透明遮罩" desc:@"默认半透明遮罩（可自定义颜色）。" buttonTitle:@"关闭" action:^{ [AlertManager dismissAnimated:YES]; }];
    [AlertManager setMaskStyle:AlertMaskStyleDefault];
    [AlertManager setMaskColor:[UIColor colorWithWhite:0.0 alpha:0.45]];
    [AlertManager showWithContentView:alertView animated:YES style:AlertAnimationStyleScale];
}

- (void)showMaskTransparentAlert {
    UIView *alertView = [self buildAlertViewWithTitle:@"全透明遮罩" desc:@"遮罩透明，背景可见且可交互（事件透传）。" buttonTitle:@"关闭" action:^{ [AlertManager dismissAnimated:YES]; }];
    alertView.backgroundColor = [UIColor colorWithRed:arc4random()%256/255.0f green:arc4random()%256/255.0f  blue:arc4random()%256/255.0f alpha:1.0f];
    [AlertManager setMaskStyle:AlertMaskStyleTransparent];
    [AlertManager showWithContentView:alertView animated:YES style:AlertAnimationStyleScale];
}

- (void)showMaskBlurAlert {
    UIView *alertView = [self buildAlertViewWithTitle:@"毛玻璃遮罩" desc:@"使用毛玻璃模糊背景，视觉聚焦弹窗。" buttonTitle:@"关闭" action:^{ [AlertManager dismissAnimated:YES]; }];
    [AlertManager setMaskStyle:AlertMaskStyleBlur];
    [AlertManager showWithContentView:alertView animated:YES style:AlertAnimationStyleScale];
}

#pragma mark - Direction Experience Demos

- (void)showDoorLeftDemo {
    [AlertManager setDefaultAnimationDirection:AlertAnimationDirectionLeft];
    UIView *alertView = [self buildAlertViewWithTitle:@"Door 左右" desc:@"门从左右打开（Left 方向）" buttonTitle:@"关闭" action:^{ [AlertManager dismissAnimated:YES]; }];
    [AlertManager showWithContentView:alertView animated:YES style:AlertAnimationStyleDoor];
}

- (void)showDoorTopDemo {
    [AlertManager setDefaultAnimationDirection:AlertAnimationDirectionTop];
    UIView *alertView = [self buildAlertViewWithTitle:@"Door 上下" desc:@"门从上下打开（Top 方向）" buttonTitle:@"关闭" action:^{ [AlertManager dismissAnimated:YES]; }];
    [AlertManager showWithContentView:alertView animated:YES style:AlertAnimationStyleDoor];
}

- (void)showExplodeTopDemo {
    [AlertManager setDefaultAnimationDirection:AlertAnimationDirectionTop];
    UIView *alertView = [self buildAlertViewWithTitle:@"Explode 从上" desc:@"碎片从上方聚合的入场演示" buttonTitle:@"关闭" action:^{ [AlertManager dismissAnimated:YES]; }];
    [AlertManager showWithContentView:alertView animated:YES style:AlertAnimationStyleExplode];
}

- (void)showGravityLeftDemo {
    [AlertManager setDefaultAnimationDirection:AlertAnimationDirectionLeft];
    // 可调高重力强度以强调侧向入场
    [AlertManager setPhysicsGravityMagnitude:220.0];
    UIView *alertView = [self buildAlertViewWithTitle:@"Gravity 从左" desc:@"重力/惯性从左侧入场" buttonTitle:@"关闭" action:^{ [AlertManager dismissAnimated:YES]; }];
    [AlertManager showWithContentView:alertView animated:YES style:AlertAnimationStyleGravity];
}

- (void)showElasticBottomDemo {
    [AlertManager setDefaultAnimationDirection:AlertAnimationDirectionBottom];
    [AlertManager setPhysicsElasticity:0.9];
    UIView *alertView = [self buildAlertViewWithTitle:@"Elastic 从下" desc:@"弹性反弹从下方入场" buttonTitle:@"关闭" action:^{ [AlertManager dismissAnimated:YES]; }];
    [AlertManager showWithContentView:alertView animated:YES style:AlertAnimationStyleElastic];
}

- (void)showSesameFrontDemo {
    [AlertManager setDefaultAnimationDirection:AlertAnimationDirectionFront];
    UIView *alertView = [self buildAlertViewWithTitle:@"Sesame 前后" desc:@"前后方向的铰链门（视觉上可能和左右类似）" buttonTitle:@"关闭" action:^{ [AlertManager dismissAnimated:YES]; }];
    [AlertManager showWithContentView:alertView animated:YES style:AlertAnimationStyleSesame];
}

- (UIView *)buildAlertViewWithTitle:(NSString *)title desc:(NSString *)desc buttonTitle:(NSString *)btnTitle action:(void(^)(void))action {
    UIView *alertView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 260, 160)];
    alertView.backgroundColor = [UIColor whiteColor];
    alertView.layer.cornerRadius = 16;
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, 260, 30)];
    label.text = title;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont boldSystemFontOfSize:18];
    [alertView addSubview:label];
    UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 60, 260, 30)];
    descLabel.text = desc;
    descLabel.textAlignment = NSTextAlignmentCenter;
    descLabel.font = [UIFont systemFontOfSize:15];
    [alertView addSubview:descLabel];
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(80, 110, 100, 40);
    [closeBtn setTitle:btnTitle forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closeAlert) forControlEvents:UIControlEventTouchUpInside];
    [alertView addSubview:closeBtn];
    return alertView;
}

- (void)closeAlert {
    [AlertManager dismissAnimated:YES];
}

@end
