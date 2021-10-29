package com.famproperties.amazon_s3_cognito

import android.content.Context
import android.util.Log
import com.amazonaws.auth.CognitoCachingCredentialsProvider
import com.amazonaws.mobile.config.AWSConfiguration
import com.amazonaws.mobileconnectors.s3.transferutility.TransferListener
import com.amazonaws.mobileconnectors.s3.transferutility.TransferNetworkLossHandler
import com.amazonaws.mobileconnectors.s3.transferutility.TransferState
import com.amazonaws.mobileconnectors.s3.transferutility.TransferUtility
import com.amazonaws.regions.Region
import com.amazonaws.services.s3.AmazonS3Client
import com.amazonaws.services.s3.S3ClientOptions
import com.amazonaws.services.s3.model.ObjectMetadata
import java.io.File
import java.io.UnsupportedEncodingException

class AwsHelper(context: Context,
                awsConfig: AWSConfiguration,
                authToken: String,
                private val imageName: String,
                private val onUploadCompleteListener: OnUploadCompleteListener) {

    private var amazonS3Client: AmazonS3Client? = null
    private var transferUtility: TransferUtility
    private var bucketName: String? = null
    private var bucketUrl: String? = null

    init {
        val userPoolMap = awsConfig.optJsonObject("CognitoUserPool")
        val regionName = userPoolMap.get("Region") as String
        val userPoolId = userPoolMap.get("PoolId") as String

        // reference: https://docs.aws.amazon.com/cognito/latest/developerguide/amazon-cognito-integrating-user-pools-with-identity-pools.html
        val credentialsProvider = CognitoCachingCredentialsProvider(context, awsConfig)
                .withLogins(mapOf("cognito-idp.$regionName.amazonaws.com/$userPoolId" to authToken))

        val s3Map = awsConfig.optJsonObject("S3TransferUtility")
        val s3RegionName = s3Map.get("Region") as String

        bucketName = s3Map.get("Bucket") as String
        bucketUrl = "https://$bucketName.s3.amazonaws.com"
        amazonS3Client = AmazonS3Client(credentialsProvider, Region.getRegion(s3RegionName))

        // skip md5 integrity check, which always fails despite successful image uploads
        amazonS3Client?.setS3ClientOptions(S3ClientOptions.builder().skipContentMd5Check(true).build())
        TransferNetworkLossHandler.getInstance(context.applicationContext)
        transferUtility = TransferUtility.builder().s3Client(amazonS3Client).context(context).build()
    }

    private val uploadedUrl: String
        get() = "$bucketUrl/$imageName"

    @Throws(UnsupportedEncodingException::class)
    fun deleteImage(): String {
        Thread(Runnable {
            amazonS3Client?.deleteObject(bucketName, imageName)
        }).start()
        onUploadCompleteListener.onUploadComplete("Success")
        return imageName
    }

    @Throws(UnsupportedEncodingException::class)
    fun uploadImage(image: File): String {

        val transferObserver = transferUtility.upload(bucketName, imageName, image, ObjectMetadata(), null, object : TransferListener {
            override fun onStateChanged(id: Int, state: TransferState) {
                print("State changed to $state")
                if (state == TransferState.COMPLETED) {
                    onUploadCompleteListener.onUploadComplete(uploadedUrl)
                }
                if (state == TransferState.FAILED) {// || state == TransferState.WAITING_FOR_NETWORK) {
                    onUploadCompleteListener.onFailed(Exception(state.toString()))
                }
            }

            override fun onProgressChanged(id: Int, bytesCurrent: Long, bytesTotal: Long) {}
            override fun onError(id: Int, ex: Exception) {
                onUploadCompleteListener.onFailed(ex)
                Log.e(TAG, "error in upload id [ " + id + " ] : " + ex.message)
            }
        })
        print("Uploading image ${transferObserver.state}")
        return uploadedUrl
    }

    @Throws(UnsupportedEncodingException::class)
    fun downloadImage(image: File): String {
        val transferObserver = transferUtility.download(bucketName, imageName, image)
        transferObserver.setTransferListener(object : TransferListener {
            override fun onStateChanged(id: Int, state: TransferState) {
                if (state == TransferState.COMPLETED) {
                    onUploadCompleteListener.onUploadComplete(image.absolutePath)
                }
                if (state == TransferState.FAILED || state == TransferState.WAITING_FOR_NETWORK) {
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

    interface OnUploadCompleteListener {
        fun onUploadComplete(imageUrl: String)
        fun onFailed(exception: Exception)
    }

    companion object {
        private val TAG = AwsHelper::class.java.simpleName
    }
}
