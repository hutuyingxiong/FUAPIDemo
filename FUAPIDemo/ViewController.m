//
//  ViewController.m
//  FUAPIDemo
//
//  Created by 刘洋 on 2017/1/9.
//  Copyright © 2017年 刘洋. All rights reserved.
//

#import "ViewController.h"
#import <GLKit/GLKit.h>
#import "FUCamera.h"
#import <FUAPIDemoBar/FUAPIDemoBar.h>


#import "FURenderer.h"
#include <sys/mman.h>
#include <sys/stat.h>
#import "authpack.h"

@interface ViewController ()<FUAPIDemoBarDelegate,FUCameraDelegate>
{
    //MARK: Faceunity
    EAGLContext *mcontext;
    int items[2];
    BOOL fuInit;
    int frameID;
    BOOL needReloadItem;
    // --------------- Faceunity ----------------
    
    FUCamera *curCamera;
}

@property (nonatomic, strong) IBOutlet FUAPIDemoBar *demoBar;//工具条

@property (nonatomic, strong) FUCamera *bgraCamera;//BGRA摄像头

@property (nonatomic, strong) FUCamera *yuvCamera;//YUV摄像头

@property (nonatomic, strong) AVSampleBufferDisplayLayer *bufferDisplayer;

@property (weak, nonatomic) IBOutlet UILabel *noTrackView;

@end

@implementation ViewController

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    [self addObserver];
    
    needReloadItem = YES;
    
    curCamera = self.bgraCamera;
    [curCamera startUp];
    
    self.bufferDisplayer.frame = self.view.bounds;
    
    
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)addObserver{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
}

//底部工具条
- (void)setDemoBar:(FUAPIDemoBar *)demoBar
{
    _demoBar = demoBar;
    _demoBar.itemsDataSource = @[@"noitem", @"tiara", @"item0208", @"YellowEar", @"PrincessCrown", @"Mood" , @"Deer" , @"BeagleDog", @"item0501", @"item0210",  @"HappyRabbi", @"item0204", @"hartshorn"];
    _demoBar.selectedItem = _demoBar.itemsDataSource[1];

    _demoBar.filtersDataSource = @[@"nature", @"delta", @"electric", @"slowlived", @"tokyo", @"warm"];
    _demoBar.selectedFilter = _demoBar.filtersDataSource[0];

    _demoBar.selectedBlur = 5;

    _demoBar.beautyLevel = 1.0;
    
    _demoBar.thinningLevel = 1.0;
    
    _demoBar.enlargingLevel = 1.0;

    _demoBar.delegate = self;
}

//bgra摄像头
- (FUCamera *)bgraCamera
{
    if (!_bgraCamera) {
        _bgraCamera = [[FUCamera alloc] init];
        
        _bgraCamera.delegate = self;
        
    }
    
    return _bgraCamera;
}

//yuv摄像头
- (FUCamera *)yuvCamera
{
    if (!_yuvCamera) {
        _yuvCamera = [[FUCamera alloc] initWithCameraPosition:AVCaptureDevicePositionFront captureFormat:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange];
        
        _yuvCamera.delegate = self;
    }
    
    return _yuvCamera;
}

//显示摄像头画面
- (AVSampleBufferDisplayLayer *)bufferDisplayer
{
    if (!_bufferDisplayer) {
        _bufferDisplayer = [[AVSampleBufferDisplayLayer alloc] init];
        _bufferDisplayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        _bufferDisplayer.frame = self.view.bounds;
        
        [self.view.layer insertSublayer:_bufferDisplayer atIndex:0];
    }
    
    return _bufferDisplayer;
}

- (void)willResignActive
{
    
    [curCamera stopCapture];
    
}

- (void)willEnterForeground
{
    
    [curCamera startCapture];
}

- (void)didBecomeActive
{
//    [curCamera startCapture];
}


#pragma -摄像头切换
- (IBAction)changeCamera:(UIButton *)sender {
    
    [self.bgraCamera changeCameraInputDeviceisFront:!self.bgraCamera.isFrontCamera];
    [self.yuvCamera changeCameraInputDeviceisFront:!self.yuvCamera.isFrontCamera];
    [curCamera startCapture];
}

#pragma -BGRA/YUV切换
- (IBAction)changeCaptureFormat:(UISegmentedControl *)sender {
    if (sender.selectedSegmentIndex == 0 && curCamera == self.yuvCamera)
    {
        [curCamera stopCapture];
        curCamera = self.bgraCamera;
    }else if (sender.selectedSegmentIndex == 1 && curCamera == self.bgraCamera){
        [curCamera stopCapture];
        curCamera = self.yuvCamera;
    }
    [curCamera startCapture];
    
}

#pragma -FUCameraDelegate
- (void)demoBarDidSelectedItem:(NSString *)item
{
    dispatch_async(curCamera.captureQueue, ^{
        needReloadItem = YES;
    });
}

#pragma -FUCameraDelegate
- (void)didOutputVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        return;
    }
    
    //如果当前环境中已存在EAGLContext，此步骤可省略，但必须要调用[EAGLContext setCurrentContext:curContext]函数。
    #warning 此步骤不可放在异步线程中执行
    [self setUpContext];
    
    //Faceunity初始化
    #warning 此步骤不可放在异步线程中执行
    if (!fuInit)
    {
        fuInit = YES;
        int size = 0;
        void *v3 = [self mmap_bundle:@"v3.bundle" psize:&size];
        
        [[FURenderer shareRenderer] setupWithData:v3 ardata:NULL authPackage:&g_auth_package authSize:sizeof(g_auth_package)];
    }
    
    //人脸跟踪
    int curTrack = fuIsTracking();
    dispatch_async(dispatch_get_main_queue(), ^{
        self.noTrackView.hidden = curTrack;
    });
    
    //切换贴纸、3D道具
    #warning 如果需要异步加载道具，需停止调用Faceunity的其他接口，否则将会产生崩溃
    if (needReloadItem) {
        needReloadItem = NO;
        [self reloadItem];
    }
    
    //加载美颜道具
    if (items[1] == 0) {
        [self loadFilter];
    }
    
    //设置美颜效果（滤镜、磨皮、美白、瘦脸、大眼....）
    fuItemSetParamd(items[1], "cheek_thinning", self.demoBar.thinningLevel); //瘦脸
    fuItemSetParamd(items[1], "eye_enlarging", self.demoBar.enlargingLevel); //大眼
    fuItemSetParamd(items[1], "color_level", self.demoBar.beautyLevel); //美白
    fuItemSetParams(items[1], "filter_name", (char *)[_demoBar.selectedFilter UTF8String]); //滤镜
    fuItemSetParamd(items[1], "blur_level", self.demoBar.selectedBlur); //磨皮
    
    //Faceunity核心接口，将道具及美颜效果作用到图像中，执行完此函数pixelBuffer即包含美颜及贴纸效果
    #warning 此步骤不可放在异步线程中执行
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    [[FURenderer shareRenderer] renderPixelBuffer:pixelBuffer withFrameId:frameID items:items itemCount:2];
    frameID += 1;
    
    #warning 执行完上一步骤，即可将pixelBuffer绘制到屏幕上或推流到服务器进行直播
    //本地显示视频图像
    
    if (self.bufferDisplayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
        [self.bufferDisplayer flush];
    }
    
    if ([self.bufferDisplayer isReadyForMoreMediaData]) {
        [self.bufferDisplayer enqueueSampleBuffer:sampleBuffer];
    }
}

#pragma -Faceunity Set EAGLContext
- (void)setUpContext
{
    if(!mcontext){
        mcontext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    }
    if(!mcontext || ![EAGLContext setCurrentContext:mcontext]){
        NSLog(@"faceunity: failed to create / set a GLES2 context");
    }
    
}

#pragma -Faceunity Load Data
- (void)reloadItem
{
    if (items[0] != 0) {
        NSLog(@"faceunity: destroy item");
        fuDestroyItem(items[0]);
    }
    
    if ([_demoBar.selectedItem isEqual: @"noitem"] || _demoBar.selectedItem == nil)
    {
        items[0] = 0;
        return;
    }
    
    int size = 0;
    
    // load selected
    void *data = [self mmap_bundle:[_demoBar.selectedItem stringByAppendingString:@".bundle"] psize:&size];
    items[0] = fuCreateItemFromPackage(data, size);
    
    NSLog(@"faceunity: load item");
}

- (void)loadFilter
{
    int size = 0;
    
    void *data = [self mmap_bundle:@"face_beautification.bundle" psize:&size];
    
    items[1] = fuCreateItemFromPackage(data, size);
}

- (void *)mmap_bundle:(NSString *)bundle psize:(int *)psize {
    
    // Load item from predefined item bundle
    NSString *str = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:bundle];
    const char *fn = [str UTF8String];
    int fd = open(fn,O_RDONLY);
    
    int size = 0;
    void* zip = NULL;
    
    if (fd == -1) {
        NSLog(@"faceunity: failed to open bundle");
        size = 0;
    }else
    {
        size = [self getFileSize:fd];
        zip = mmap(nil, size, PROT_READ, MAP_SHARED, fd, 0);
    }
    
    *psize = size;
    return zip;
}

- (int)getFileSize:(int)fd
{
    struct stat sb;
    sb.st_size = 0;
    fstat(fd, &sb);
    return (int)sb.st_size;
}

@end

