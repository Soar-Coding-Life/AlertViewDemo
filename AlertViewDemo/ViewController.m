//
//  ViewController.m
//  AlertViewDemo
//
//  Created by 王贵彬 on 2025/8/14.
//

#import "ViewController.h"
#import "AlertDemoListViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (IBAction)pushDemo:(id)sender {
    [self.navigationController pushViewController:[AlertDemoListViewController new] animated:YES];
}

@end
