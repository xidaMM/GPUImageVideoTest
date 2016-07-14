//
//  ViewController.swift
//  GPUImageTest
//
//  Created by 希达 on 16/7/7.
//  Copyright © 2016年 希达. All rights reserved.
//

import UIKit
import GPUImage
let capturePreset = 720 //屏幕分辨率 在屏幕显示的宽度
import AssetsLibrary

class ViewController: UIViewController {

    @IBOutlet weak var beginOrStopBtn: UIButton!
    @IBOutlet weak var previewView: GPUImageView!
    var videoCamera:GPUImageVideoCameraEx?
    //裁剪滤镜
    var cropFilter:GPUImageCropFilter?
    //美颜滤镜
    var isBeauty:Bool = false
    var beautyFilter:GPUImageBeautifyFilter?
    var movieWriter:GPUImageMovieWriterEx?
    //滤镜分组
    var filterGroup:GPUImageFilterGroup?
    var movieUrl:NSURL?
    @IBOutlet weak var timeLabel: UILabel!
    var pathToMovie:NSString?
    var timeLabelTime = 0
    var mTimer:NSTimer?
    //现在的视频的摄像头前置后置
    var currentCameraPosition:AVCaptureDevicePosition = AVCaptureDevicePosition.Back
    //MARK: lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view, typically from a nib.
        createVideoCamera(currentCameraPosition)
    }

    @IBAction func beautyFileAddOrDeleteClicked(sender: UIButton) {
        cancelBtnClicked(sender)
        isBeauty = !isBeauty
        createVideoCamera(currentCameraPosition)
    }
    @IBAction func changeCameraPositionClicked(sender: UIButton) {
        cancelBtnClicked(sender)
        if currentCameraPosition == AVCaptureDevicePosition.Front {
            createVideoCamera(.Back)
            currentCameraPosition = AVCaptureDevicePosition.Back
        }else {
            createVideoCamera(.Front)
            currentCameraPosition = AVCaptureDevicePosition.Front
        }
    }
    //MARK: 创建相机和滤镜
    func createVideoCamera(frontOrBack:AVCaptureDevicePosition) {
        videoCamera?.removeAllTargets()
        videoCamera = nil
        //摄像头
        self.videoCamera = GPUImageVideoCameraEx(sessionPreset: AVCaptureSessionPresetiFrame1280x720, cameraPosition: frontOrBack)
        self.videoCamera?.outputImageOrientation = .Portrait
        //表示不是镜像
        self.videoCamera?.horizontallyMirrorFrontFacingCamera = true
        //裁剪滤镜
        self.cropFilter = GPUImageCropFilter(cropRegion: CGRect(x: 0, y: (1280-720)/2/1280.0, width: 1, height: 720/1280.0))
        //美颜

        self.beautyFilter = GPUImageBeautifyFilter()
        self.filterGroup = GPUImageFilterGroup()
        //set
        self.previewView.fillMode = kGPUImageFillModePreserveAspectRatioAndFill
            //GPUImageFillModeTypePreserveAspectRatioAndFill
        timeLabelTime = 0
        beginOrStopBtn.tag = 0
        //响应链
        if isBeauty {
            self.cropFilter?.addTarget(beautyFilter)
            filterGroup?.addTarget(cropFilter)
            filterGroup?.addTarget(beautyFilter)
            filterGroup?.initialFilters = [cropFilter!]
            filterGroup?.terminalFilter = beautyFilter
            filterGroup?.forceProcessingAtSize(previewView.frame.size)
            filterGroup?.useNextFrameForImageCapture()
            self.videoCamera?.addTarget(filterGroup)
            self.filterGroup?.addTarget(self.previewView as GPUImageView)
        }else {
            self.videoCamera?.addTarget(cropFilter)
            self.cropFilter?.addTarget(self.previewView as GPUImageView)
            self.videoCamera?.addTarget(filterGroup)
            self.filterGroup?.addTarget(self.previewView as GPUImageView)
        }

        self.videoCamera?.startCameraCapture()
    }
    //MARK:func
    //根据时间生成路径
    func getVideoPath() -> String {
        let time = NSDate().timeIntervalSince1970
        return (NSHomeDirectory() as NSString).stringByAppendingPathComponent("Documents/\(Int(time)).m4v")
    }
    //开始录制 
    func beginVideoWriter()  {
        pathToMovie = getVideoPath()
        movieUrl = NSURL(fileURLWithPath: pathToMovie! as String)
        unlink(pathToMovie!.UTF8String)// 如果已经存在文件，AVAssetWriter会有异常，删除旧文件
//         let videoSettings = [AVVideoCodecKey:AVVideoCodecH264,AVVideoWidthKey:capturePreset,AVVideoHeightKey:capturePreset]
//        movieWriter = GPUImageMovieWriter(movieURL: movieUrl!, size: CGSize(width: capturePreset, height: 960), fileType: AVFileTypeMPEG4, outputSettings: videoSettings as [NSObject : AnyObject])
//        movieWriter = GPUImageMovieWriter(movieURL: movieUrl!, size: CGSize(width: capturePreset, height: 1280))
        movieWriter = GPUImageMovieWriterEx(movieURL: movieUrl!, size: CGSize(width: capturePreset, height: capturePreset))

        movieWriter?.paused = false
        movieWriter?.encodingLiveVideo = true
//        cropFilter?.addTarget(movieWriter)
//        movieWriter?.hasAudioTrack = true
        videoCamera?.addAudioInputsAndOutputs()
        videoCamera?.audioEncodingTarget = movieWriter

        self.onTimer()
        mTimer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: "onTimer", userInfo: nil, repeats: true)
        if isBeauty {
            filterGroup?.addTarget(movieWriter)
            movieWriter?.startRecording()
        }else {
            cropFilter?.addTarget(movieWriter)
            movieWriter?.startRecording()
        }


    }
    func onTimer() {
        timeLabelTime = timeLabelTime + 1
        timeLabel.text = "\(timeLabelTime)s"
    }
    //暂停录制
    func stopVideoWriter()  {
        movieWriter?.pauseRecording()
//        movieWriter?.paused = true
        videoCamera?.pauseCameraCapture()
        mTimer?.pauseTimer()
    }

    //MARK: click
    //开始或者暂停点击
    @IBAction func btnClicked(sender: UIButton) {
        //开始
        if sender.titleLabel?.text == "开始" {
            if sender.tag == 0 {
                sender.setTitle("暂停", forState: UIControlState.Normal)
                beginVideoWriter()
                sender.tag = 1
            }else {
                movieWriter?.resumeRecording()
//                movieWriter?.paused = false
                videoCamera?.resumeCameraCapture()
                mTimer?.resumeTimer()
                sender.setTitle("暂停", forState: UIControlState.Normal)
            }
        }else {//暂停
            sender.setTitle("开始", forState: UIControlState.Normal)
            stopVideoWriter()
        }
    }
    //取消录制
    @IBAction func cancelBtnClicked(sender: UIButton) {

        movieWriter?.cancelRecording()
        resetShow()
    }
    //取消录制或结束录制的时候 界面显示刷新
    func resetShow() {
        timeLabelTime = -1
        onTimer()
        mTimer?.pauseTimer()
        beginOrStopBtn.setTitle("开始", forState: UIControlState.Normal)
    }
    //把录制好的视频写相册
    func savePhotoCamera(path:String) {
        let library = ALAssetsLibrary()
        if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(path) {
            library.writeVideoAtPathToSavedPhotosAlbum(movieUrl, completionBlock: { (url:NSURL!, err:NSError?) in
                dispatch_async(dispatch_get_main_queue(), {
                    if (err == nil) {
                        let alert = UIAlertView(title: "", message: "保存视频成功", delegate: self, cancelButtonTitle: "ok")
                        alert.show()
                    }else {
                        let alert = UIAlertView(title: "", message: "保存视频失败", delegate: self, cancelButtonTitle: "ok")
                        alert.show()
                    }
                })
            })
        }
    }
    //结束录制
    @IBAction func endVideoWriter(sender: UIButton) {
        beginOrStopBtn.tag = 0
        resetShow()
        movieWriter?.finishRecording()
        cropFilter?.removeTarget(movieWriter)
        beautyFilter?.removeTarget(movieWriter)
        filterGroup?.removeTarget(movieWriter)
        videoCamera?.audioEncodingTarget = nil
        savePhotoCamera(pathToMovie! as String)
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
//    开启和关闭闪光灯：
//
//    [videoCamera.inputCamerasetTorchMode:AVCaptureTorchModeOn];
//    [videoCamera.inputCameraunlockForConfiguration];
//
//    [videoCamera.inputCameralockForConfiguration:nil];
//    [videoCamera.inputCamerasetTorchMode:AVCaptureTorchModeOff];
//    [videoCamera.inputCameraunlockForConfiguration];
    //    var captureSession:AVCaptureSession?// 协调AV输入设备到AVoutput的数据流
    //    var inputCamera:AVCaptureDevice?//摄像头设备
    //    var microphone:AVCaptureDevice?//麦克风设备
    //    var videoInput:AVCaptureDeviceInput?//摄像头输入
    //    var videoOutput:AVCaptureVideoDataOutput?//摄像头输出
    //    var audioInput:AVCaptureDeviceInput?//麦克风输入
    //    var audioOutput:AVCaptureAudioDataOutput?//麦克风输出
    //    var assetWriter:AVAssetWriter?//把多媒体数据写入文件的类
    //    var assetWriterAudioInput:AVAssetWriterInput?//音频输入
    //    var assetWriterVideoInput:AVAssetWriterInput?//视频输入
    //    var assetWriterPixelBufferInput:AVAssetWriterInputPixelBufferAdaptor?//视频输入适配器

}

extension NSTimer {
    func pauseTimer()  {
        if !self.valid {
            return
        }
        self.fireDate = NSDate.distantFuture()
    }
    func resumeTimer()  {
        if !self.valid {
            return
        }
        self.fireDate = NSDate()
    }
}



















