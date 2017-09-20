//
//  OpticalIDScanner.swift
//  NYU-ID-Scanner
//
//  Created by Cole Smith on 9/11/17.
//  Copyright © 2017 Cole Smith. All rights reserved.
//

import UIKit
import SwiftOCR
import AVFoundation

class OpticalIDScanner: NSObject, AVCapturePhotoCaptureDelegate {
    
    // MARK: - OCR Class Properties
    
    /// OCR Instance
    let ocr: SwiftOCR!
    
    // MARK: - Camera Class Properties
    
    private var captureSession: AVCaptureSession!
    private var cameraOutput: AVCapturePhotoOutput!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    
    /// Callback that is assigned at takePhoto(), and called from capture()
    private var cameraCompletion: ((UIImage) -> Void)?
    
    // MARK: - Initializers
    
    override init() {
        ocr = SwiftOCR()
        super.init()
    }
    
    deinit {
        
        // The camera is not always needed for this library
        // so only kill capturesession if it exists
        if let cs = captureSession {
            cs.stopRunning()
        }
    }
    
    // MARK: - Scanning Functions
    
    /**
     
     Given a UIImage, returns the string in that image. The image
     should have been taken using the provided camera view, with the
     N Number in its proper bounding box.
     
     - Parameter image: The image received from the camera scanner
     - Parameter rect:  Optional bounding box to crop the image to
     
     - Returns: A `String` of the found information (which may be incorrect)
     
     */
    func scan(image: UIImage, rect: CGRect?, completion: @escaping (String) -> Void) {
        if let r = rect {
            ocr.recognizeInRect(image, rect: r) { str in
                completion(str)
            }
        } else {
            ocr.recognize(image) { str in
                completion(str)
            }
        }
    }
    
    /**
     
     Given a UIImage, returns the NNumber in that image.
     
     - Parameter image: The image received from the camera scanner
     - Parameter rect:  Optional bounding box to crop the image to
     
     - Returns: A completion handler with the last 8 characters of the 
                found string, which is *likely* to be the N Number.
     
     */
    func scanForNNumber(image: UIImage, rect: CGRect?, completion: @escaping (String) -> Void) {
        scan(image: image, rect: rect) { str in
            let nNumberOffset = str.index(str.startIndex, offsetBy: 9)
            completion(str.substring(from: nNumberOffset))
        }
    }
    
    /**
     
     Starts the camera
     
     - Parameter preview: A UIView to display the camera stream preview
     
     - Returns: Completion handler with NNumber string, empty string on error
     
     */
    func scanNNumberFromCamera(completion: @escaping (UIImage) -> Void) {
        
        // Make sure captureSession is live
        if captureSession == nil {
            print("[ ERR ] Could not take photo: Capture Session not started")
            return
        }
        
        // Take photo
        takePhoto() { img in
            
            // Crop image to preview layer size on screen
            guard let previewImg = self.cropToPreviewLayer(img) else {
                print("[ ERR ] Could not crop image")
//                completion("")
                return
            }
            
            // Crop image again to size of bounding box on screen
            let cropBox = self.getCropBox(width: previewImg.size.width, height: previewImg.size.height)
            guard let boundingImg = self.cropImage(img: previewImg, toRect: cropBox) else {
                print("[ ERR ] Could not crop image")
//                completion("")
                return
            }
            
            completion(boundingImg)
            
            // Run OCR on final image
            self.scanForNNumber(image: boundingImg, rect: nil) { nnumber in
                print(nnumber)
            }
        }
    }
    
    // MARK: - Camera Functions
    
    /**
     
     Starts the camera
     
     - Returns: `nil`
     
     */
    func startCamera(previewView: UIView?) {
        
        // Check for access to camera
        AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo) {
            (granted: Bool) -> Void in
            guard granted else { return }
        }
        
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        cameraOutput = AVCapturePhotoOutput()
        
        let device = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)

        if let input = try? AVCaptureDeviceInput(device: device) {
            if (captureSession.canAddInput(input)) {
                captureSession.addInput(input)
                if (captureSession.canAddOutput(cameraOutput)) {
                    captureSession.addOutput(cameraOutput)
                    
                    // Change Orientation to Portrait
                    let connection = cameraOutput.connection(withMediaType: AVMediaTypeVideo)
                    if let supported = connection?.isVideoOrientationSupported {
                        if supported {
                            connection?.videoOrientation = .portrait
                        }
                    }
                    
                    // Add the preview view, if one was provided
                    if let preview = previewView {
                        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
                        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
                        previewLayer.frame = preview.bounds
                        preview.layer.addSublayer(previewLayer)
                    }
                    
                    // Begin Camera Capture
                    captureSession.startRunning()
                }
            } else {
                print("[ ERR ] Camera Capture Failed")
            }
        } else {
            print("[ ERR ] Camera Capture Failed")
        }
    }
    
    /**
     
     Initiates taking a photo, which invokes the capture method
     for delegate (self). Photo is stored in `currentFrame` var.
     
     - Returns: `nil`
     
     */
    private func takePhoto(completion: @escaping (UIImage) -> Void) {
        let settings = AVCapturePhotoSettings()
        let previewPixelType = settings.availablePreviewPhotoPixelFormatTypes.first!
        let previewFormat = [
                             kCVPixelBufferPixelFormatTypeKey as String: Int64(previewPixelType),
                             kCVPixelBufferWidthKey as String: Int64(previewLayer.frame.width),
                             kCVPixelBufferHeightKey as String: Int64(previewLayer.frame.width),
                            ]
        settings.previewPhotoFormat = previewFormat
        cameraOutput.capturePhoto(with: settings, delegate: self)
        
        // Bring completion into class scope so that it may return from capture()
        cameraCompletion = completion
    }
    

    func capture(_ captureOutput: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer
        photoSampleBuffer: CMSampleBuffer?,
        previewPhotoSampleBuffer: CMSampleBuffer?,
        resolvedSettings: AVCaptureResolvedPhotoSettings,
        bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?)
    {
        if let error = error {
            print("[ ERR ] Error in Capture method: " + error.localizedDescription)
            return
        }
        
        // Get JPEG from samplebuffer, and then convert to UIImage
        if let sampleBuffer = photoSampleBuffer,
           let previewBuffer = previewPhotoSampleBuffer,
           let dataImage = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: sampleBuffer,
                                                                            previewPhotoSampleBuffer: previewBuffer)
        {
            // Convert to UIImage and invoke the camera callback
            if let img = UIImage(data: dataImage), let comp = cameraCompletion {
                comp(img)
            } else {
                print("[ ERR ] Could not capture frame")
            }
        }
    }
    
    // MARK: - Utility Functions
    
    /**
     
     Crops the rendered image from the camera to the exact dimensions
     of the preview layer displayed on the device
     
     - Parameter img: The image to crop
     
     - Returns: Optional `UIImage`, `nil` on error
     
     */
    private func cropToPreviewLayer(_ img: UIImage) -> UIImage? {
        
        // Get output proportions
        let outputRect = previewLayer.metadataOutputRectOfInterest(for: previewLayer.bounds)
        
        // Get CGImage
        guard let cgImage = img.cgImage else {
            print("[ ERR ] Could not get CGImage when cropping")
            return nil
        }
        
        // Compute bounding box
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let cropRect = CGRect(x: outputRect.origin.x * width,
                              y: outputRect.origin.y * height,
                              width: outputRect.size.width * width,
                              height: outputRect.size.height * height
        )
        
        // Crop CGImage
        guard let cgImageCropped = cgImage.cropping(to: cropRect) else {
            print("[ ERR ] Could not crop CGImage")
            return nil
        }
        
        return UIImage(cgImage: cgImageCropped, scale: 1.0, orientation: img.imageOrientation)
    }
    
    /**
     
     Crops a UIImage to the specified rectangle
     
     - Parameter img: The image to crop
     - Parameter rect: The rectangle to crop to
     
     - Returns: Optional `UIImage`, `nil` on error
     
     */
    private func cropImage(img: UIImage, toRect rect:CGRect) -> UIImage? {

        // IMPORTANT NOTE ---------------------------------------------
        // The values for the crop rect must be swapped since the image
        // was taken in portrat mode. Orientation info is lost when
        // converting to CGRect, but restored upon UIImage creation
        // after cropping. Thus, the rect must be converted for crop.
//        var rect = rect
//        let x = rect.origin.x
//        let y = rect.origin.y
//        let w = rect.width
//        let h = rect.height
//        rect = CGRect(x: y, y: x, width: h, height: w)
        let rotated = img.rotated(by: Measurement(value: 90.0, unit: UnitAngle.degrees), options: [])!
        
        guard let imageRef = rotated.cgImage?.cropping(to: rect) else {
            return nil
        }
        
        return UIImage(cgImage: imageRef, scale: img.scale, orientation: img.imageOrientation)
    }
    
    /**
     
     Generates a crop box for the center of the image. The
     crop box will be 1/2 the width and 1/8 the height
     of the provided values
     
     - Parameter width: Width of full image
     - Parameter height: Height of full image
     
     - Returns: `CGRect` of crop box
     
     */
    func getCropBox(width: CGFloat, height: CGFloat) -> CGRect {
        let centerX = width / 2.0
        let centerY = height / 2.0

        let cropW = (1/3) * width
        let cropH = (1/8) * height
        let cropX = centerX - (cropW / 2.0)
        let cropY = centerY - (cropH / 2.0)
        
        return CGRect(x: cropX, y: cropY, width: cropW, height: cropH)
    }
}

// Extension to rotate raw image data for OCR
// From: https://stackoverflow.com/a/39804312/4487982
extension UIImage {
    struct RotationOptions: OptionSet {
        let rawValue: Int
        
        static let flipOnVerticalAxis = RotationOptions(rawValue: 1)
        static let flipOnHorizontalAxis = RotationOptions(rawValue: 2)
    }
    
    func rotated(by rotationAngle: Measurement<UnitAngle>, options: RotationOptions = []) -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }
        
        let rotationInRadians = CGFloat(rotationAngle.converted(to: .radians).value)
        let transform = CGAffineTransform(rotationAngle: rotationInRadians)
        var rect = CGRect(origin: .zero, size: self.size).applying(transform)
        rect.origin = .zero
        
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        return renderer.image { renderContext in
            renderContext.cgContext.translateBy(x: rect.midX, y: rect.midY)
            renderContext.cgContext.rotate(by: rotationInRadians)
            
            let x = options.contains(.flipOnVerticalAxis) ? -1.0 : 1.0
            let y = options.contains(.flipOnHorizontalAxis) ? 1.0 : -1.0
            renderContext.cgContext.scaleBy(x: CGFloat(x), y: CGFloat(y))
            
            let drawRect = CGRect(origin: CGPoint(x: -self.size.width/2, y: -self.size.height/2), size: self.size)
            renderContext.cgContext.draw(cgImage, in: drawRect)
        }
    }
}
