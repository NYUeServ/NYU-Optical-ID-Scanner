# NYU-Optical-ID-Scanner
## Scans NYU IDs using machine vision

### Description
This app uses an OCR (Optical Character Recognition) trained neural net
to parse images for NYU NetIDs. Users line up the NetID in the bounding box
and the app will crop the image, isolate the text, and run the text through
the neural net. The found text is then printed to the console.

### Installation
The installation involves changing the neural net to support the trained
model for NetIDs. To do this, follow these steps:

1. Navigate to project directory and run `pod install`
2. Copy the `OCR-Network` file to `Pods/SwiftOCR` and 
replace the current network
3. In the file `Pods/SwiftOCR/SwiftOCR.swift` change line number 33 to read:

    `public var recognizableCharacters = "NetID:0123456789"`

### Known Issues
* SwiftOCR is not perfect, and accuracy is around 90%
* This project is halted due to the critical issue of image manipulation
* SwiftOCR reads images in a raw form, meaning we must rotate 
images directly. This is incredibly slow.
* SwiftOCR will crash when it does not recognize any text.

### Moving Forward
In order to use this project for its intended purpose, we would need to do
a few things:

* Use a different, more reobust OCR program.
* Rotate the UI to landscape mode to remove the need to rotate images
* Train our model on actual NYU ID cards (huge undertaking)
