import Flutter
import UIKit
import AWSS3
import AWSCore
import AWSCognitoIdentityProvider

public class SwiftAmazonS3CognitoPlugin: NSObject, FlutterPlugin {

    var s3BucketName: String?
    var s3RegionName: String?
    var s3Region: AWSRegionType?

    var userPoolId: String?
    var userPoolAppClientId: String?
    var userPoolRegionName: String?
    var userPoolRegion: AWSRegionType?

    var idPoolId: String?
    var idPoolRegionName: String?
    var idPoolRegion: AWSRegionType?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "amazon_s3_cognito", binaryMessenger: registrar.messenger())
    let instance = SwiftAmazonS3CognitoPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
          initConfig()
          if (call.method.elementsEqual("uploadImage")) {
              uploadImageForRegion(call,result: result)
          } else if (call.method.elementsEqual("downloadImage")) {
              downloadImageForRegion(call,result: result)
          } else if (call.method.elementsEqual("deleteImage")) {
              deleteImage(call,result: result)
          }
      }

    /// reads config from awsconfiguration.json in Runner/config/<env>/,
    /// where <env> is one of dev, qa, uat, or prod.
    func initConfig() {
        let s3Config = AWSInfo().defaultServiceInfo("S3TransferUtility")
        s3BucketName = s3Config?.infoDictionary["Bucket"] as? String
        s3RegionName = (s3Config?.infoDictionary["Region"] as? String)?.uppercased()
        s3Region = getRegion(name: s3RegionName!)

        let userPoolConfig = AWSInfo().defaultServiceInfo("CognitoUserPool")
        userPoolId = userPoolConfig?.infoDictionary["PoolId"] as? String
        userPoolAppClientId = userPoolConfig?.infoDictionary["AppClientId"] as? String
        userPoolRegionName = (userPoolConfig?.infoDictionary["Region"] as? String)?.uppercased()
        userPoolRegion = getRegion(name: userPoolRegionName!)

        // for identity pool config, need to get root dictionary and go from there
        let defaultConfig = AWSInfo.default().rootInfoDictionary
        let credsProviderConfig = defaultConfig["CredentialsProvider"] as? NSDictionary
        let idPoolConfig = credsProviderConfig?["CognitoIdentity"] as? NSDictionary
        let idPoolDefaultConfig = idPoolConfig?["Default"] as? NSDictionary
        idPoolId = idPoolDefaultConfig?["PoolId"] as? String
        idPoolRegionName = (idPoolDefaultConfig?["Region"] as? String)?.uppercased()
        idPoolRegion = getRegion(name: idPoolRegionName!)
    }

    public func nameGenerator() -> String{
          let date = Date()
          let formatter = DateFormatter()
          formatter.dateFormat = "ddMMyyyy"
          let result = formatter.string(from: date)
          return "IMG" + result + String(Int64(date.timeIntervalSince1970 * 1000)) + "jpeg"
      }

      func uploadImageForRegion(_ call: FlutterMethodCall, result: @escaping FlutterResult){
          let arguments = call.arguments as? NSDictionary
          let imagePath = arguments!["filePath"] as? String
          let fileName = arguments!["imageName"] as? String
          let authToken = arguments!["authToken"] as? String
          let contentTypeParam = arguments!["contentType"] as? String

          var imageAmazonUrl = ""
          let fileUrl = NSURL(fileURLWithPath: imagePath!)

        var contentType = "image/jpeg"
        if(contentTypeParam != nil &&
            contentTypeParam!.count > 0){
            contentType = contentTypeParam!
        }

        if(contentTypeParam == nil || contentTypeParam!.count == 0 &&  fileName!.contains(".")){
                       var index = fileName!.lastIndex(of: ".")
                       index = fileName!.index(index!, offsetBy: 1)
                       if(index != nil){
                           let extention = String(fileName![index!...])
                           print("extension"+extention);
                           if(extention.lowercased().contains("png") ||
                           extention.lowercased().contains("jpg") ||
                               extention.lowercased().contains("jpeg") ){
                               contentType = "image/"+extention
                           }else{

                            if(extention.lowercased().contains("pdf")){
                                contentType = "application/pdf"
                                }else{
                                contentType = "application/*"
                                }
                           }
                       }
                   }

          let serviceConfiguration = AWSServiceConfiguration(region: s3Region!, credentialsProvider: nil)
          let userPoolConfiguration = AWSCognitoIdentityUserPoolConfiguration(clientId: userPoolAppClientId!, clientSecret: nil, poolId: userPoolId!)
          AWSCognitoIdentityUserPool.register(with: serviceConfiguration, userPoolConfiguration: userPoolConfiguration, forKey: "UserPool")

          let pool = AWSCognitoIdentityUserPool(forKey: "UserPool")
          let credentialsProvider = AWSCognitoCredentialsProvider(regionType: idPoolRegion!, identityPoolId: idPoolId!, identityProviderManager:pool)
          let configuration = AWSServiceConfiguration(region: userPoolRegion!, credentialsProvider: credentialsProvider)
          AWSServiceManager.default().defaultServiceConfiguration = configuration

          let uploadRequest = AWSS3TransferManagerUploadRequest()
          uploadRequest?.bucket = s3BucketName
          uploadRequest?.key = fileName
          uploadRequest?.contentType = contentType
          uploadRequest?.body = fileUrl as URL

          AWSS3TransferManager.default().upload(uploadRequest!).continueWith { (task) -> AnyObject? in
              if let error = task.error {
                  print("❌ Upload failed: (\(error))")
              }

              if task.result != nil {
                imageAmazonUrl = "https://s3-\(self.s3RegionName!).amazonaws.com/\(self.s3BucketName!)/\(uploadRequest!.key!)"
                  print("✅ Upload complete: (\(imageAmazonUrl))")
              } else {
                  print("❌ Unexpected empty result.")
              }
              result(imageAmazonUrl)
              return nil
          }
      }

      func downloadImageForRegion(_ call: FlutterMethodCall, result: @escaping FlutterResult){
                let arguments = call.arguments as? NSDictionary
                let imagePath = arguments!["filePath"] as? String
                let fileName = arguments!["imageName"] as? String

                var imageAmazonUrl = ""
                let fileUrl = NSURL(fileURLWithPath: imagePath!)

                let uploadRequest = AWSS3TransferManagerDownloadRequest()
                uploadRequest?.bucket = s3BucketName
                uploadRequest?.key = fileName
                uploadRequest?.downloadingFileURL = fileUrl as URL

                let credentialsProvider = AWSCognitoCredentialsProvider(regionType: idPoolRegion!, identityPoolId: idPoolId!)
                let configuration = AWSServiceConfiguration(region: userPoolRegion!, credentialsProvider: credentialsProvider)
                AWSServiceManager.default().defaultServiceConfiguration = configuration

                AWSS3TransferManager.default().download(uploadRequest!).continueWith { (task) -> AnyObject? in
                    if let error = task.error {
                        print("❌ Download failed (\(error))")
                    }

                    if task.result != nil {
                        imageAmazonUrl = imagePath!
                        print("✅ Download successed (\(imageAmazonUrl))")
                    } else {
                        print("❌ Unexpected empty result.")
                    }
                    result(imageAmazonUrl)
                    return nil
                }
            }

      func deleteImage(_ call: FlutterMethodCall, result: @escaping FlutterResult){
          let arguments = call.arguments as? NSDictionary
          let fileName = arguments!["imageName"] as? String

          let credentialsProvider = AWSCognitoCredentialsProvider(regionType: idPoolRegion!, identityPoolId: idPoolId!)
          let configuration = AWSServiceConfiguration(region: userPoolRegion!, credentialsProvider: credentialsProvider)
          AWSServiceManager.default().defaultServiceConfiguration = configuration

          AWSS3.register(with: configuration!, forKey: "defaultKey")
          let s3 = AWSS3.s3(forKey: "defaultKey")
          let deleteObjectRequest = AWSS3DeleteObjectRequest()
          deleteObjectRequest?.bucket = s3BucketName
          deleteObjectRequest?.key = fileName
          s3.deleteObject(deleteObjectRequest!).continueWith { (task:AWSTask) -> AnyObject? in
              if let error = task.error {
                  print("Error occurred: \(error)")
                  result("Error occurred: \(error)")
                  return nil
              }
              print("image deleted successfully.")
              result("image deleted successfully.")
              return nil
          }
      }

      public func getRegion( name:String ) -> AWSRegionType{
          if (name == "US-EAST-1"){
              return AWSRegionType.USEast1
          } else if(name == "AP-SOUTHEAST-1"){
              return AWSRegionType.APSoutheast1
          } else if(name == "US-EAST-2"){
              return AWSRegionType.USEast2
          } else if(name == "EU-WEST-1"){
              return AWSRegionType.EUWest1
          } else if(name == "CA-CENTRAL-1"){
              return AWSRegionType.CACentral1
          } else if(name == "CN-NORTH-1"){
              return AWSRegionType.CNNorth1
          } else if(name == "CN-NORTHWEST-1"){
              return AWSRegionType.CNNorthWest1
          } else if(name == "EU-CENTRAL-1"){
              return AWSRegionType.EUCentral1
          } else if(name == "EU-WEST-2"){
              return AWSRegionType.EUWest2
          } else if(name == "EU-WEST-3"){
              return AWSRegionType.EUWest3
          } else if(name == "SA-EAST-1"){
              return AWSRegionType.SAEast1
          } else if(name == "US-WEST-1"){
              return AWSRegionType.USWest1
          } else if(name == "US-WEST-2"){
              return AWSRegionType.USWest2
          } else if(name == "AP-NORTHEAST-1"){
              return AWSRegionType.APNortheast1
          } else if(name == "AP-NORTHEAST-2"){
              return AWSRegionType.APNortheast2
          } else if(name == "AP-SOUTHEAST-1"){
              return AWSRegionType.APSoutheast1
          } else if(name == "AP-SOUTHEAST-2"){
              return AWSRegionType.APSoutheast2
          } else if(name == "AP-SOUTH-1"){
              return AWSRegionType.APSouth1
          } else if(name == "ME-SOUTH-1"){
            return AWSRegionType.MESouth1
          }
          return AWSRegionType.Unknown
      }
}
