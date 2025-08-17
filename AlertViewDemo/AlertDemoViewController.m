#import "AlertDemoViewController.h"
#import "AlertManager.h"

@implementation AlertDemoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    UIButton *showBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    showBtn.frame = CGRectMake(60, 200, 200, 50);
    [showBtn setTitle:@"弹出自定义弹窗" forState:UIControlStateNormal];
    [showBtn addTarget:self action:@selector(showAlert) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:showBtn];
}

- (void)showAlert {
    UIView *alertView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 260, 160)];
    alertView.backgroundColor = [UIColor whiteColor];
    alertView.layer.cornerRadius = 16;
    alertView.layer.masksToBounds = YES;
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 30, 260, 30)];
    label.text = @"这是一个弹窗示例";
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont boldSystemFontOfSize:18];
    [alertView addSubview:label];
    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(80, 100, 100, 40);
    [closeBtn setTitle:@"关闭弹窗" forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(closeAlert) forControlEvents:UIControlEventTouchUpInside];
    [alertView addSubview:closeBtn];
    [AlertManager showWithContentView:alertView animated:YES];
}

- (void)closeAlert {
    [AlertManager dismissAnimated:YES];
}

@end
