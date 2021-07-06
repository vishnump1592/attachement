//
//  Attachment.swift
//
//
//  Created by Vishnu's Mac on 06/07/21.
//

import Foundation
import UIKit
import MobileCoreServices
import AVFoundation
import Photos



class Attachment: NSObject {
    static let shared = Attachment()
    fileprivate var viewController: UIViewController?
    
    //MARK: - Properties
    var imageSelectionClousre: ((UIImage) -> Void)?
    var videoSelectionClousre: ((NSURL) -> Void)?
    var documentSelectionClousre: ((URL) -> Void)?
    
    //MARK: - showAttachmentActionSheet
    // This function is used to show the attachment sheet for image, video, photo and file.
    func showAttachmentActionSheet(vc: UIViewController) {
        viewController = vc
        let actionSheet = UIAlertController(title: Text.actionFileTypeHeading, message: Text.actionFileTypeDescription, preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: Text.camera, style: .default, handler: { (action) -> Void in
            self.authorisationStatus(.camera, vc: self.viewController!)
        }))
        
        actionSheet.addAction(UIAlertAction(title: Text.phoneLibrary, style: .default, handler: { (action) -> Void in
            self.authorisationStatus(.photoLibrary, vc: self.viewController!)
        }))
        
        actionSheet.addAction(UIAlertAction(title: Text.video, style: .default, handler: { (action) -> Void in
            self.authorisationStatus(.video, vc: self.viewController!)
            
        }))
        
        actionSheet.addAction(UIAlertAction(title: Text.file, style: .default, handler: { (action) -> Void in
            self.documentPicker()
        }))
        
        actionSheet.addAction(UIAlertAction(title: Text.cancel, style: .cancel, handler: nil))
        
        vc.present(actionSheet, animated: true, completion: nil)
    }
    
    //MARK: - Authorisation Status
    func authorisationStatus(_ attachmentType: AttachmentType, vc: UIViewController){
        viewController = vc
        
        let status = PHPhotoLibrary.authorizationStatus()
        switch status {
        case .authorized:
            if attachmentType == AttachmentType.camera {
                openCamera()
            }
            if attachmentType == AttachmentType.photoLibrary {
                photoLibrary()
            }
            if attachmentType == AttachmentType.video {
                videoLibrary()
            }
        case .denied:
            self.showAlert(attachmentType)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization({ (status) in
                if status == PHAuthorizationStatus.authorized {
                    if attachmentType == AttachmentType.camera {
                        self.openCamera()
                    }
                    if attachmentType == AttachmentType.photoLibrary {
                        self.photoLibrary()
                    }
                    if attachmentType == AttachmentType.video {
                        self.videoLibrary()
                    }
                }else{
                    self.showAlert(attachmentType)
                }
            })
        case .restricted:
            self.showAlert(attachmentType)
        default:
            break
        }
    }
    
    //MARK: - CAMERA
    func openCamera(){
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let myPickerController = UIImagePickerController()
            myPickerController.delegate = self
            myPickerController.sourceType = .camera
            viewController?.present(myPickerController, animated: true, completion: nil)
        }
    }
    

    //MARK: - IMAGE PICKER
    func photoLibrary() {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let myPickerController = UIImagePickerController()
            myPickerController.delegate = self
            myPickerController.sourceType = .photoLibrary
            viewController?.present(myPickerController, animated: true, completion: nil)
        }
    }
    
    //MARK: - VIDEO PICKER
    func videoLibrary() {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            let myPickerController = UIImagePickerController()
            myPickerController.delegate = self
            myPickerController.sourceType = .photoLibrary
            myPickerController.mediaTypes = [kUTTypeMovie as String, kUTTypeVideo as String]
            viewController?.present(myPickerController, animated: true, completion: nil)
        }
    }
    
    //MARK: - DOCUMENT PICKER
    func documentPicker() {
        let importMenu = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf])
        importMenu.delegate = self
        importMenu.modalPresentationStyle = .formSheet
        viewController?.present(importMenu, animated: true, completion: nil)
    }
    
    //MARK: -  ALERT
    func showAlert(_ attachmentType: AttachmentType) {
        var alertTitle: String = ""
        if attachmentType == AttachmentType.camera {
            alertTitle = Text.cameraAccessMessage
        }
        if attachmentType == AttachmentType.photoLibrary {
            alertTitle = Text.photoLibraryMessage
        }
        if attachmentType == AttachmentType.video {
            alertTitle = Text.videoLibraryMessage
        }
        
        let cameraUnavailableAlertController = UIAlertController (title: alertTitle , message: nil, preferredStyle: .alert)
        
        let settingsAction = UIAlertAction(title: Text.settings, style: .destructive) { (_) -> Void in
            let settingsUrl = NSURL(string:UIApplication.openSettingsURLString)
            if let url = settingsUrl {
                UIApplication.shared.open(url as URL, options: [:], completionHandler: nil)
            }
        }
        let cancelAction = UIAlertAction(title: Text.cancel, style: .default, handler: nil)
        cameraUnavailableAlertController .addAction(cancelAction)
        cameraUnavailableAlertController .addAction(settingsAction)
        viewController?.present(cameraUnavailableAlertController , animated: true, completion: nil)
    }
}

extension Attachment: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        viewController?.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[UIImagePickerController.InfoKey(rawValue: UIImagePickerController.InfoKey.originalImage.rawValue)] as? UIImage {
            self.imageSelectionClousre?(image)
        } else {
            print("Something went wrong")
        }
        
        if let videoUrl = info[UIImagePickerController.InfoKey(rawValue: UIImagePickerController.InfoKey.mediaURL.rawValue)] as? NSURL {
            compressWithSessionStatusFunc(videoUrl)
        }
        else {
            print("Something went wrong")
        }
        viewController?.dismiss(animated: true, completion: nil)
    }
    
    //MARK: Video Compression
    fileprivate func compressWithSessionStatusFunc(_ videoUrl: NSURL) {
        let compressedURL = NSURL.fileURL(withPath: NSTemporaryDirectory() + NSUUID().uuidString + ".MOV")
        compressVideo(inputURL: videoUrl as URL, outputURL: compressedURL) { (exportSession) in
            guard let session = exportSession else { return }
            switch session.status {
            case .unknown:
                break
            case .waiting:
                break
            case .exporting:
                break
            case .completed:
                DispatchQueue.main.async {
                    self.videoSelectionClousre?(compressedURL as NSURL)
                }
            case .failed:
                break
            case .cancelled:
                break
            default:
                    break
            }
        }
    }
    
    func compressVideo(inputURL: URL, outputURL: URL, completion:@escaping (_ exportSession: AVAssetExportSession?)-> Void) {
        let urlAsset = AVURLAsset(url: inputURL, options: nil)
        guard let exportSession = AVAssetExportSession(asset: urlAsset, presetName: AVAssetExportPreset1280x720) else {
            completion(nil)
            return
        }
        exportSession.outputURL = outputURL
        exportSession.outputFileType = AVFileType.mov
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.exportAsynchronously { () -> Void in
            completion(exportSession)
        }
    }
}

extension Attachment: UIDocumentPickerDelegate {
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        controller.delegate = self
        viewController?.present(controller, animated: true, completion: nil)
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        self.documentSelectionClousre?(url)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        viewController?.dismiss(animated: true, completion: nil)
    }
}


enum AttachmentType: String{
    case camera, video, photoLibrary
}


//MARK: - Constants
struct Text {
    static let actionFileTypeHeading = "Add a File"
    static let actionFileTypeDescription = "Choose a filetype to add..."
    static let camera = "Camera"
    static let phoneLibrary = "Phone Library"
    static let video = "Video"
    static let file = "File"
    static let photoLibraryMessage = "App does not have access to your photos. To enable access, tap settings and turn on Photo Library Access."
    static let cameraAccessMessage = "App does not have access to your camera. To enable access, tap settings and turn on Camera."
    static let videoLibraryMessage = "App does not have access to your video. To enable access, tap settings and turn on Video Library Access."
    static let settings = "Settings"
    static let cancel = "Cancel"
}
