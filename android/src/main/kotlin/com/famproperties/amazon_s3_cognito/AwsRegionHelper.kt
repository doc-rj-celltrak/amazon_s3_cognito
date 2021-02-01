package com.famproperties.amazon_s3_cognito

import java.io.File
import java.io.UnsupportedEncodingException

import android.content.Context
import android.util.Log

import com.amazonaws.auth.CognitoCachingCredentialsProvider
import com.amazonaws.mobile.config.AWSConfiguration
import com.amazonaws.mobileconnectors.s3.transferutility.*
import com.amazonaws.regions.Region
import com.amazonaws.services.s3.AmazonS3Client
import com.amazonaws.services.s3.S3ClientOptions

class AwsRegionHelper(private val context: Context, private val onUploadCompleteListener: OnUploadCompleteListener,
                      private val IMAGE_NAME: String, AUTH_TOKEN: String) {

    private var amazonS3Client: AmazonS3Client? = null
    private var transferUtility: TransferUtility
    private var nameOfUploadedFile: String? = null
    private var bucketName: String? = null
    private var bucketUrl: String? = null

    init {
        // read config from awsconfiguration.json in android/app/src/<env>/res/raw/,
        // where <env> is one of dev, qa, uat, or prod.
        val config = AWSConfiguration(context)
        config.configuration = "Default"
        val userPoolMap = config.optJsonObject("CognitoUserPool")
        val regionName = userPoolMap.get("Region") as String
        val userPoolId = userPoolMap.get("PoolId") as String

        // reference: https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-integrating-user-pools-with-identity-pools.html
        val credentialsProvider = CognitoCachingCredentialsProvider(context, AWSConfiguration(context))
                .withLogins(mapOf("cognito-idp.$regionName.amazonaws.com/$userPoolId" to AUTH_TOKEN))

        val s3Map = config.optJsonObject("S3TransferUtility")
        val s3RegionName = s3Map.get("Region") as String

        bucketName = s3Map.get("Bucket") as String
        bucketUrl = "https://s3-$s3RegionName.amazonaws.com/$bucketName"
        amazonS3Client = AmazonS3Client(credentialsProvider, Region.getRegion(s3RegionName))

        // skip md5 integrity check, which always fails despite successful image uploads
        amazonS3Client?.setS3ClientOptions(S3ClientOptions.builder().skipContentMd5Check(true).build())
        TransferNetworkLossHandler.getInstance(context.applicationContext)
        transferUtility = TransferUtility.builder().s3Client(amazonS3Client).context(context).build()
    }

    private val uploadedUrl: String
        get() = "$bucketUrl/$nameOfUploadedFile"

    @Throws(UnsupportedEncodingException::class)
    fun deleteImage(): String {
        Thread(Runnable{
            amazonS3Client?.deleteObject(bucketName, IMAGE_NAME)
        }).start()
        onUploadCompleteListener.onUploadComplete("Success")
        return IMAGE_NAME
    }

    @Throws(UnsupportedEncodingException::class)
    fun uploadImage(image: File): String {
        nameOfUploadedFile = IMAGE_NAME
        val transferObserver = transferUtility.upload(bucketName, nameOfUploadedFile, image)

        transferObserver.setTransferListener(object : TransferListener {
            override fun onStateChanged(id: Int, state: TransferState) {
                if (state == TransferState.COMPLETED) {
                    onUploadCompleteListener.onUploadComplete(uploadedUrl)
                }
                if (state == TransferState.FAILED ||  state == TransferState.WAITING_FOR_NETWORK) {
                    onUploadCompleteListener.onFailed(Exception(state.toString()))
                }
            }

            override fun onProgressChanged(id: Int, bytesCurrent: Long, bytesTotal: Long) {}
            override fun onError(id: Int, ex: Exception) {
                onUploadCompleteListener.onFailed(ex)
                Log.e(TAG, "error in upload id [ " + id + " ] : " + ex.message)
            }
        })
        return uploadedUrl
    }

    @Throws(UnsupportedEncodingException::class)
    fun downloadImage(image: File): String {
        nameOfUploadedFile = IMAGE_NAME
        val transferObserver = transferUtility.download(bucketName, nameOfUploadedFile, image)

        transferObserver.setTransferListener(object : TransferListener {
            override fun onStateChanged(id: Int, state: TransferState) {
                if (state == TransferState.COMPLETED) {
                    onUploadCompleteListener.onUploadComplete(image.absolutePath)
                }
                if (state == TransferState.FAILED ||  state == TransferState.WAITING_FOR_NETWORK) {
                    onUploadCompleteListener.onFailed(Exception(state.toString()))
                }
            }

            override fun onProgressChanged(id: Int, bytesCurrent: Long, bytesTotal: Long) {}
            override fun onError(id: Int, ex: Exception) {
                onUploadCompleteListener.onFailed(ex)
                Log.e(TAG, "error in upload id [ " + id + " ] : " + ex.message)
            }
        })
        return uploadedUrl
    }

    @Throws(UnsupportedEncodingException::class)
    fun clean(filePath: String): String {
        return filePath.replace("[^.A-Za-z0-9]".toRegex(), "")
    }

    interface OnUploadCompleteListener {
        fun onUploadComplete(imageUrl: String)
        fun onFailed(exception: Exception)
    }

    companion object {
        private val TAG = AwsRegionHelper::class.java.simpleName
        private const val URL_TEMPLATE = "https://s3.amazonaws.com/%s/%s"
    }
}
