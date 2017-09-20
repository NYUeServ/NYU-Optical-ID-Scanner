//
//  ViewController.swift
//  NYU-ID-Scanner
//
//  Created by Cole Smith on 9/11/17.
//  Copyright © 2017 Cole Smith. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var preview: UIView!
    
    @IBOutlet weak var captured: UIImageView!
    
    var scanner: OpticalIDScanner!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        scanner = OpticalIDScanner()
        let img = UIImage(named: "testID")
        scanner.scan(image: img!, rect: nil) {
            str in
            print(str)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        scanner.startCamera(previewView: preview)
        
        let box = CropBox(frame: scanner.getCropBox(width: preview.bounds.width, height: preview.bounds.height))
        box.draw(scanner.getCropBox(width: preview.bounds.width, height: preview.bounds.height))
        preview.addSubview(box)
        box.center = CGPoint(x: preview.bounds.size.width / 2.0, y: preview.bounds.size.height / 2.0)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func capturePressed(_ sender: Any) {
        scanner.scanNNumberFromCamera() { nnumber in
            self.captured.image = nnumber
//            print(nnumber)
        }
    }
}

class CropBox: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isOpaque = false
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Draw yellow bounding box for scanner
    public override func draw(_ frame: CGRect) {
        let x = frame.origin.x
        let y = frame.origin.y
        let h = frame.height
        let w = frame.width
        let context = UIGraphicsGetCurrentContext()
        context?.setStrokeColor(UIColor.yellow.cgColor)
        context?.setLineWidth(2.0)
        context?.stroke(CGRect(x: x, y: y, width: w, height: h))
    }
}

