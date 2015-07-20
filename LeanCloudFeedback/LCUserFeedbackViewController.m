//
//  LCUserFeedbackViewController.m
//  Feedback
//
//  Created by yang chaozhong on 4/24/14.
//  Copyright (c) 2014 LeanCloud. All rights reserved.
//

#import "LCUserFeedbackViewController.h"
#import "LCUserFeedbackReplyCell.h"
#import "LCUserFeedbackThread.h"
#import "LCUserFeedbackThread_Internal.h"
#import "LCUserFeedbackReply.h"
#import "LCUserFeedbackAgent.h"

#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)

#define TOP_MARGIN 20.0f

#define TAG_TABLEView_Header 1
#define TAG_InputFiled 2

static CGFloat const kInputViewHeight = 48;
static CGFloat const kContactHeaderHeight = 48;

@interface LCUserFeedbackViewController () <UITableViewDelegate, UITableViewDataSource> {
    NSMutableArray *_feedbackReplies;
    LCUserFeedbackThread *_userFeedback;
}

@property(nonatomic, strong) UIRefreshControl *refreshControl;
@property(nonatomic, strong) UITableView *tableView;
@property(nonatomic, strong) UITextField *tableViewHeader;
@property(nonatomic, strong) UITextField *inputTextField;
@property(nonatomic, strong) UIButton *sendButton;
@property(nonatomic, strong) UIBarButtonItem *closeButtonItem;

@end

@implementation LCUserFeedbackViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        self.navigationBarStyle = LCUserFeedbackNavigationBarStyleBlue;
        self.contactHeaderHidden = NO;
        self.feedbackCellFont = [UIFont systemFontOfSize:16];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _feedbackReplies = [[NSMutableArray alloc] init];
    
    [self setupUI];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self keyboardWillHide:nil];

    [self loadFeedbackThreads];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    // 记录最后阅读时，看到了多少条反馈
    if (_userFeedback !=nil && _feedbackReplies.count > 0) {
        NSString *localKey = [NSString stringWithFormat:@"feedback_%@", _userFeedback.objectId];
        [[NSUserDefaults standardUserDefaults] setObject:@(_feedbackReplies.count) forKey:localKey];
    }
}

- (void)setupUI {
    self.navigationItem.leftBarButtonItem = self.closeButtonItem;
    [self.navigationItem setTitle:@"意见反馈"];
    [self setupNavigaionBarStyle];
    
    [self.view addSubview:self.tableView];
    [self.view addSubview:self.inputTextField];
    [self.view addSubview:self.sendButton];

    [[[LCUserFeedbackReplyCell class] appearance] setCellFont:self.feedbackCellFont];
    
    [_tableView addSubview:self.refreshControl];
}

#pragma mark - Properties

- (UIBarButtonItem *)closeButtonItem {
    if (_closeButtonItem == nil) {
        UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *closeButtonImage = [UIImage imageNamed:@"LeanCloudFeedback/back.png"];
        if (!closeButtonImage) {
            closeButtonImage = [UIImage imageNamed:@"back.png"];
        }
        [closeButton setImage:closeButtonImage forState:UIControlStateNormal];
        closeButton.frame = CGRectMake(0, 0, closeButtonImage.size.width, closeButtonImage.size.height);
        closeButton.autoresizingMask = UIViewAutoresizingFlexibleHeight;
        [closeButton addTarget:self action:@selector(closeButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
        
        _closeButtonItem = [[UIBarButtonItem alloc] initWithCustomView:closeButton];
    }
    return _closeButtonItem;
}


- (UITableView *)tableView {
    if (_tableView == nil) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.frame), CGRectGetHeight(self.view.frame) - kInputViewHeight)
                                                      style:UITableViewStylePlain];
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.delegate = self;
        _tableView.dataSource = self;
    }
    return _tableView;
}

- (UITextField *)inputTextField {
    if (_inputTextField == nil) {
        _inputTextField = [[UITextField alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(self.view.frame) - kInputViewHeight, CGRectGetWidth(self.view.frame)-60, kInputViewHeight)];
        _inputTextField.tag = TAG_InputFiled;
        [_inputTextField setFont:[UIFont systemFontOfSize:12]];
        [_inputTextField setBackgroundColor:[UIColor colorWithRed:247.0f/255 green:248.0f/255 blue:248.0f/255 alpha:1]];
        _inputTextField.placeholder = @"填写反馈";
        UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 5, 30)];
        _inputTextField.leftView = paddingView;
        _inputTextField.leftViewMode = UITextFieldViewModeAlways;
        _inputTextField.returnKeyType = UIReturnKeyDone;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
        _inputTextField.delegate = (id <UITextFieldDelegate>) self;
    }
    return _inputTextField;
}

- (UIButton *)sendButton {
    if (_sendButton == nil) {
        _sendButton = [UIButton buttonWithType:UIButtonTypeSystem];
        _sendButton.frame = CGRectMake(CGRectGetWidth(self.view.frame) - 60, CGRectGetHeight(self.view.frame) - kInputViewHeight, 60, kInputViewHeight);
        [_sendButton.titleLabel setFont:[UIFont systemFontOfSize:12]];
        [_sendButton setTitleColor:[UIColor colorWithRed:137.0f/255 green:137.0f/255 blue:137.0f/255 alpha:1] forState:UIControlStateNormal];
        [_sendButton setTitle:@"发送" forState:UIControlStateNormal];
        [_sendButton setBackgroundColor:[UIColor colorWithRed:247.0f/255 green:248.0f/255 blue:248.0f/255 alpha:1]];
        [_sendButton addTarget:self action:@selector(sendButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _sendButton;
}

- (void)setupNavigaionBarStyle {
    switch (self.navigationBarStyle) {
        case LCUserFeedbackNavigationBarStyleBlue:
            [self.navigationController.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor whiteColor]}];
            if (SYSTEM_VERSION_LESS_THAN(@"7.0")) {
                [self.navigationController.navigationBar setBackgroundColor:[UIColor colorWithRed:85.0f/255 green:184.0f/255 blue:244.0f/255 alpha:1]];
            } else {
                [self.navigationController.navigationBar setBarTintColor:[UIColor colorWithRed:85.0f/255 green:184.0f/255 blue:244.0f/255 alpha:1]];
            }
            break;
        case LCUserFeedbackNavigationBarStyleNone:
            break;
        default:
            break;
    }
}

- (UIRefreshControl *)refreshControl {
    if (_refreshControl == nil) {
        _refreshControl = [[UIRefreshControl alloc] init];
        [_refreshControl addTarget:self action:@selector(handleRefresh:) forControlEvents:UIControlEventValueChanged];
    }
    return _refreshControl;
}

#pragma mark -

- (void)fetchRepliesWithBlock:(AVArrayResultBlock)block {
    [LCUserFeedbackThread fetchFeedbackWithBlock:^(LCUserFeedbackThread *feedback, NSError *error) {
        if (error) {
            block(nil, error);
        } else {
            if (feedback) {
                _userFeedback = feedback;
                [_userFeedback fetchFeedbackRepliesInBackgroundWithBlock:block];
            } else {
                block([NSArray array], nil);
            }
        }
    }];
}

- (void)loadFeedbackThreads {
    if (![_refreshControl isRefreshing]) {
        [_refreshControl beginRefreshing];
    }
    [self fetchRepliesWithBlock:^(NSArray *objects, NSError *error) {
        [_refreshControl endRefreshing];
        if ([self filterError:error]) {
            if (objects.count > 0) {
                [_feedbackReplies removeAllObjects];
                [_feedbackReplies addObjectsFromArray:objects];
                
                [_tableView reloadData];
                [self scrollToBottom];
            }
        }
    }];
}

- (void)handleRefresh:(id)sender {
    [self loadFeedbackThreads];
}

- (void)closeButtonClicked:(id)sender {
    [self dismissViewControllerAnimated:YES completion:^{
        ;
    }];
}

- (void)alertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"好的" otherButtonTitles:nil, nil];
    [alertView show];
}

- (BOOL)filterError:(NSError *)error {
    if (error) {
        [self alertWithTitle:@"出错了" message:[error description]];
        return NO;
    } else {
        return YES;
    }
}

- (NSString *)currentContact {
    NSString *contact = self.tableViewHeader.text;
    return contact.length > 0 ? contact : _contact;
}

- (void)disableSendButton {
    self.sendButton.enabled = NO;
}

- (void)enableSendButton {
    self.sendButton.enabled = YES;
}

- (void)sendButtonClicked:(id)sender {
    NSString *contact = [self currentContact];
    NSString *content = self.inputTextField.text;
    if (content.length) {
        [self disableSendButton];
        
        if (!_userFeedback) {
            NSString *title = _feedbackTitle ?: content;
            _contact = contact;
            [LCUserFeedbackThread feedbackWithContent:title contact:_contact create:YES withBlock:^(id object, NSError *error) {
                if ([self filterError:error]) {
                    _userFeedback = object;
                    [self createFeedbackReplyWithFeedback:_userFeedback content:content];
                } else {
                    [self enableSendButton];
                }
            }];
        } else {
            [self createFeedbackReplyWithFeedback:_userFeedback content:content];
        }
    }
}

- (void)createFeedbackReplyWithFeedback:(LCUserFeedbackThread *)feedback content:(NSString *)content {
    LCUserFeedbackReply *feedbackReply = [LCUserFeedbackReply feedbackReplyWithContent:content type:@"user"];
    [_userFeedback saveFeedbackReplyInBackground:feedbackReply withBlock:^(id object, NSError *error) {
        if ([self filterError:error]) {
            [_feedbackReplies addObject:feedbackReply];
            [self.tableView reloadData];
            [self scrollToBottom];
            
            if ([_inputTextField isFirstResponder]) {
                [_inputTextField resignFirstResponder];
            }
            
            if ([_inputTextField.text length] > 0) {
                _inputTextField.text = @"";
            }
        }
        [self enableSendButton];
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

#pragma mark - UIKeyboard Notification
- (void)keyboardWillShow:(NSNotification *)notification {
    if ([self.tableViewHeader isFirstResponder]) {
        return;
    }
    
    float animationDuration = [[[notification userInfo] valueForKey:UIKeyboardAnimationDurationUserInfoKey] floatValue];
    CGFloat keyboardHeight = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size.height;
    
    [UIView animateWithDuration:animationDuration
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         
                         CGRect inputTextFiledFrame = self.inputTextField.frame;
                         inputTextFiledFrame.origin.y = self.view.bounds.size.height - keyboardHeight - inputTextFiledFrame.size.height;
                         self.inputTextField.frame = inputTextFiledFrame;
                         
                         CGRect sendButtonFrame = self.sendButton.frame;
                         sendButtonFrame.origin.y = self.view.bounds.size.height - keyboardHeight - sendButtonFrame.size.height;
                         self.sendButton.frame = sendButtonFrame;
                         
                         CGRect tableViewFrame = self.tableView.frame;
                         tableViewFrame.size.height = self.view.bounds.size.height - self.navigationController.navigationBar.frame.size.height - keyboardHeight;
                         self.tableView.frame = tableViewFrame;
                     }
                     completion:^(BOOL finished) {
                         [self scrollToBottom];
                     }
     ];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    if ([self.tableViewHeader isFirstResponder]) {
        return;
    }
    
    [UIView beginAnimations:@"bottomBarDown" context:nil];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    
    CGRect inputTextFieldFrame = self.inputTextField.frame;
    inputTextFieldFrame.origin.y = self.view.bounds.size.height - inputTextFieldFrame.size.height;
    self.inputTextField.frame = inputTextFieldFrame;
    
    CGRect sendButtonFrame = self.sendButton.frame;
    sendButtonFrame.origin.y = self.view.bounds.size.height - sendButtonFrame.size.height;
    self.sendButton.frame = sendButtonFrame;
    
    CGRect tableViewFrame = self.tableView.frame;
    tableViewFrame.size.height = CGRectGetHeight(self.view.frame) - kInputViewHeight;
    self.tableView.frame = tableViewFrame;
    
    [UIView commitAnimations];
}

#pragma mark UITextField Delegate Methods

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField.tag == TAG_TABLEView_Header && [textField.text length] > 0 && _userFeedback) {
        _userFeedback.contact = textField.text;
        [LCUserFeedbackThread updateFeedback:_userFeedback withBlock:^(id object, NSError *error) {
            if ([self filterError:error]) {
                [self alertWithTitle:@"提示" message:@"更改成功"];
            }
        }];
    }
}
#pragma mark - UIScrollViewDelegate
- (void)scrollToBottom {
    if ([self.tableView numberOfRowsInSection:0] > 1) {
        NSInteger lastRowNumber = [self.tableView numberOfRowsInSection:0] - 1;
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:lastRowNumber inSection:0];
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:YES];
    }
}

#pragma mark - UITableViewDelegate and UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_feedbackReplies count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (self.contactHeaderHidden) {
        return 0;
    } else {
        return kContactHeaderHeight;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    self.tableViewHeader = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 320, kContactHeaderHeight)];
    UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 30)];
    self.tableViewHeader.leftView = paddingView;
    self.tableViewHeader.leftViewMode = UITextFieldViewModeAlways;
    
    self.tableViewHeader.delegate = (id <UITextFieldDelegate>) self;
    self.tableViewHeader.tag = TAG_TABLEView_Header;
    [self.tableViewHeader setBackgroundColor:[UIColor colorWithRed:247.0f/255 green:248.0f/255 blue:248.0f/255 alpha:1]];
    self.tableViewHeader.textAlignment = NSTextAlignmentLeft;
    self.tableViewHeader.placeholder = @"Email或QQ号";
    [self.tableViewHeader setFont:[UIFont systemFontOfSize:12.0f]];
    if (_contact) {
        self.tableViewHeader.text = _contact;
    }
    return _tableViewHeader;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *content = ((LCUserFeedbackReply *)_feedbackReplies[indexPath.row]).content;
    
    CGSize labelSize = [content sizeWithFont:[UIFont systemFontOfSize:12.0f]
                           constrainedToSize:CGSizeMake(226.0f, MAXFLOAT)
                               lineBreakMode:NSLineBreakByWordWrapping];
    
    return labelSize.height + 40 + TOP_MARGIN;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    LCUserFeedbackReply *feedbackReply = _feedbackReplies[indexPath.row];
    static NSString *cellIdentifier = @"feedbackReplyCell";
    LCUserFeedbackReplyCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[LCUserFeedbackReplyCell alloc] initWithFeedbackReply:feedbackReply reuseIdentifier:cellIdentifier];;
    }
    [cell configuareCellWithFeedbackReply:feedbackReply];
    return cell;
}


@end


