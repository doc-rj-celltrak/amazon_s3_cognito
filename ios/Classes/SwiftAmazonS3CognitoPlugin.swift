import Flutter
import UIKit
import AWSS3
import AWSCore
import AWSCognitoIdentityProvider

public class SwiftAmazonS3CognitoPlugin: NSObject, FlutterPlugin {
    
    var awsServiceConfiguration: AWSServiceConfiguration?
    var s3TransferUtility: AWSS3TransferUtility?
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
        initialize()
        if (call.method.elementsEqual("uploadImage")) {
            uploadImage(call,result: result)
        } else if (call.method.elementsEqual("downloadImage")) {
            downloadImage(call,result: result)
        } else if (call.method.elementsEqual("deleteImage")) {
            deleteImage(call,result: result)
        }
    }
    
    func initialize() {
        initConfig()
        
        // reference: https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-integrating-user-pools-with-identity-pools.html
        let serviceConfiguration = AWSServiceConfiguration(region: s3Region!, credentialsProvider: nil)
        let userPoolConfiguration = AWSCognitoIdentityUserPoolConfiguration(clientId: userPoolAppClientId!, clientSecret: nil, poolId: userPoolId!)
        AWSCognitoIdentityUserPool.register(with: serviceConfiguration, userPoolConfiguration: userPoolConfiguration, forKey: "UserPool")
        
        let pool = AWSCognitoIdentityUserPool(forKey: "UserPool")
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType: idPoolRegion!, identityPoolId: idPoolId!, identityProviderManager:pool)
        awsServiceConfiguration = AWSServiceConfiguration(region: userPoolRegion!, credentialsProvider: credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = awsServiceConfiguration
        
        s3TransferUtility = AWSS3TransferUtility.default()
    }
    
    /// reads config from awsconfiguration.json in Runner/config/<env>/,
    /// where <env> is one of dev, qa, uat, or prod.
    func initConfig() {
        let s3Config = AWSInfo.default().defaultServiceInfo("S3TransferUtility")
        s3BucketName = s3Config?.infoDictionary["Bucket"] as? String
        s3RegionName = (s3Config?.infoDictionary["Region"] as? String)?.uppercased()
        s3Region = getRegion(name: s3RegionName!)
        
        let userPoolConfig = AWSInfo.default().defaultServiceInfo("CognitoUserPool")
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
    
    public func nameGenerator() -> String {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "ddMMyyyy"
        let result = formatter.string(from: date)
        return "IMG" + result + String(Int64(date.timeIntervalSince1970 * 1000)) + "jpeg"
    }
    
    func uploadImage(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? NSDictionary
        let imagePath = arguments!["filePath"] as? String
        let fileName = arguments!["imageName"] as? String
        let contentTypeParam = arguments!["contentType"] as? String
        
        var imageAmazonUrl = ""
        let fileUrl = NSURL(fileURLWithPath: imagePath!)
        
        var contentType = "image/jpeg"
        if (contentTypeParam != nil && contentTypeParam!.count > 0) {
            contentType = contentTypeParam!
        }
        
        if (contentTypeParam == nil || contentTypeParam!.count == 0 && fileName!.contains(".")) {
            var index = fileName!.lastIndex(of: ".")
            index = fileName!.index(index!, offsetBy: 1)
            if (index != nil) {
                let extension1 = String(fileName![index!...])
                print("extension" + extension1);
                if (extension1.lowercased().contains("png") ||
                        extension1.lowercased().contains("jpg") ||
                        extension1.lowercased().contains("jpeg")) {
                    contentType = "image/" + extension1
                } else {
                    if (extension1.lowercased().contains("pdf")) {
                        contentType = "application/pdf"
                    } else {
                        contentType = "application/*"
                    }
                }
            }
        }
        
        s3TransferUtility?.uploadFile(fileUrl as URL, bucket: s3BucketName!, key: fileName!, contentType: contentType, expression: nil, completionHandler: nil).continueWith {
            (task) -> AnyObject? in
            
            if let error = task.error {
                print("❌ Upload did fail: (\(error))")
                result(S3Error(error: error).asFlutterError)
            }
            
            else if (task.result != nil) {
                imageAmazonUrl = "https://\(self.s3BucketName!).s3.amazonaws.com/\(fileName!)"
                print("✅ Upload complete: (\(imageAmazonUrl))")
                result(imageAmazonUrl)
            } else {
                print("❌ Unexpected empty result.")
                result(S3Error.emptyResponse.asFlutterError)
            }
            
            return nil
        }
    }
    
    func downloadImage(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? NSDictionary
        let imagePath = arguments!["filePath"] as? String
        let fileName = arguments!["imageName"] as? String
        
        var resultUrl = ""
        let fileUrl = NSURL(fileURLWithPath: imagePath!)
        
        s3TransferUtility?.download(to: fileUrl as URL, bucket: s3BucketName!, key: fileName!, expression: nil, completionHandler: nil).continueWith {
            (task) -> AnyObject? in if let error = task.error {
                print("❌ Download failed: (\(error))")
            }
        
        if (task.result != nil) {
            resultUrl = imagePath!
            print("✅ Download complete: (\(resultUrl))")
        } else {
            print("❌ Unexpected empty result.")
        }
        
        result(resultUrl)
        return nil
        }
    }
    
    func deleteImage(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? NSDictionary
        let fileName = arguments!["imageName"] as? String
        
        AWSS3.register(with: awsServiceConfiguration!, forKey: "defaultKey")
        let s3 = AWSS3.s3(forKey: "defaultKey")
        let deleteObjectRequest = AWSS3DeleteObjectRequest()
        deleteObjectRequest?.bucket = s3BucketName
        deleteObjectRequest?.key = fileName
        s3.deleteObject(deleteObjectRequest!).continueWith {
            (task:AWSTask) -> AnyObject? in if let error = task.error {
                print("Error occurred in deleteImage: \(error)")
                result("Error occurred: \(error)")
                return nil
            }
        
        print("image deleted successfully.")
        result("image deleted successfully.")
        return nil
        }
    }
    
    func getRegion( name:String ) -> AWSRegionType {
        if (name == "US-EAST-1") {
            return AWSRegionType.USEast1
        } else if(name == "AP-SOUTHEAST-1") {
            return AWSRegionType.APSoutheast1
        } else if(name == "US-EAST-2") {
            return AWSRegionType.USEast2
        } else if(name == "EU-WEST-1") {
            return AWSRegionType.EUWest1
        } else if(name == "CA-CENTRAL-1") {
            return AWSRegionType.CACentral1
        } else if(name == "CN-NORTH-1") {
            return AWSRegionType.CNNorth1
        } else if(name == "CN-NORTHWEST-1") {
            return AWSRegionType.CNNorthWest1
        } else if(name == "EU-CENTRAL-1") {
            return AWSRegionType.EUCentral1
        } else if(name == "EU-WEST-2") {
            return AWSRegionType.EUWest2
        } else if(name == "EU-WEST-3") {
            return AWSRegionType.EUWest3
        } else if(name == "SA-EAST-1") {
            return AWSRegionType.SAEast1
        } else if(name == "US-WEST-1") {
            return AWSRegionType.USWest1
        } else if(name == "US-WEST-2") {
            return AWSRegionType.USWest2
        } else if(name == "AP-NORTHEAST-1")  {
            return AWSRegionType.APNortheast1
        } else if(name == "AP-NORTHEAST-2"){
            return AWSRegionType.APNortheast2
        } else if(name == "AP-SOUTHEAST-1") {
            return AWSRegionType.APSoutheast1
        } else if(name == "AP-SOUTHEAST-2") {
            return AWSRegionType.APSoutheast2
        } else if(name == "AP-SOUTH-1") {
            return AWSRegionType.APSouth1
        } else if(name == "ME-SOUTH-1") {
            return AWSRegionType.MESouth1
        }
        return AWSRegionType.Unknown
    }
}

enum S3Error: String, Error {
    // Timed out. Could be offline, server could be stalled, etc. Should retry
    case requestTimedOut
    // Temporarily offline, obviously should retry
    case requestOffline
    // The file is gone, this is a permanent error, no retries
    case fileNotFound
    // The reason varies - missing params, 400 response, missing upload data, etc.
    // These are seemingly bug type errors and 400's, so hopefully a restart will fix.
    case clientError
    // Some null pointer error hack and 5xx response from server, so retryable
    case serverError
    // We got a redirect. assuming it's transient so retryable.
    case redirection
    // since we got an otherwise non-error response hopefully it's all good, so no retry
    case emptyResponse
    
    // Random exception in upload task. Seems like a bug would cause, so we'll retry
    case unknown
    
    public init(error:Error) {
        let nserror = error as NSError
        if nserror.domain == AWSS3TransferUtilityErrorDomain,
           let errorCode = AWSS3TransferUtilityErrorType(rawValue: nserror.code) {
            
            switch errorCode {
            
            case AWSS3TransferUtilityErrorType.redirection:
                self = .redirection
            case AWSS3TransferUtilityErrorType.clientError:
                self = .clientError
            case AWSS3TransferUtilityErrorType.serverError:
                self = .serverError
            case AWSS3TransferUtilityErrorType.localFileNotFound:
                self = .fileNotFound
            case AWSS3TransferUtilityErrorType.unknown:
                self = .unknown
            // can't happen
            @unknown default:
                self = .unknown
            }
        } else if nserror.domain == NSURLErrorDomain {
            let offlineErrors = [
                NSURLErrorUnknown,
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorDNSLookupFailed,
                NSURLErrorHTTPTooManyRedirects,
                NSURLErrorResourceUnavailable,
                NSURLErrorNotConnectedToInternet,
                NSURLErrorRedirectToNonExistentLocation,
                NSURLErrorBadServerResponse,
                NSURLErrorUserCancelledAuthentication,
                NSURLErrorUserAuthenticationRequired,
                NSURLErrorZeroByteResource,
                NSURLErrorCannotDecodeRawData,
                NSURLErrorCannotDecodeContentData,
                NSURLErrorCannotParseResponse,
                NSURLErrorSecureConnectionFailed,
                NSURLErrorDataNotAllowed
            ]
            
            if nserror.code == NSURLErrorTimedOut {
                self = .requestTimedOut
            } else if offlineErrors.contains(nserror.code) {
                self = .requestOffline
            } else {
                self = .unknown
            }
        } else {
            self = .unknown
        }
    }
    
    var asFlutterError:FlutterError {
        FlutterError(code: rawValue, message: nil, details: nil)
    }
}
