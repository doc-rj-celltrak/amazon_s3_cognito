package com.famproperties.amazon_s3_cognito

import java.io.File
import java.io.UnsupportedEncodingException

import android.content.Context
import android.util.Log

import com.amazonaws.auth.CognitoCachingCredentialsProvider
import com.amazonaws.mobileconnectors.s3.transferutility.*
import com.amazonaws.regions.Region
import com.amazonaws.regions.Regions
import com.amazonaws.services.s3.AmazonS3Client
import com.amazonaws.services.s3.S3ClientOptions

class AwsRegionHelper(private val context: Context, private val onUploadCompleteListener: OnUploadCompleteListener,
                      private val BUCKET_NAME: String, private val IDENTITY_POOL_ID: String,
                      private val IMAGE_NAME: String, private val REGION: String, private val SUB_REGION: String,
                      USER_POOL_ID: String, AUTH_TOKEN: String) {

    private var transferUtility: TransferUtility
    private var nameOfUploadedFile: String? = null
    private var region1:Regions = Regions.DEFAULT_REGION
    private var subRegion1:Regions = Regions.DEFAULT_REGION

    init {
        initRegion()

        val credentialsProvider = CognitoCachingCredentialsProvider(context, IDENTITY_POOL_ID, region1)
        credentialsProvider.logins =
                mapOf("cognito-idp."+region1.getName()+".amazonaws.com/"+USER_POOL_ID to AUTH_TOKEN)

        val amazonS3Client = AmazonS3Client(credentialsProvider, Region.getRegion(subRegion1))
        // skip md5 integrity check, which always fails despite successful image uploads
        amazonS3Client.setS3ClientOptions(S3ClientOptions.builder().skipContentMd5Check(true).build())
        TransferNetworkLossHandler.getInstance(context.applicationContext)

        transferUtility = TransferUtility.builder().s3Client(amazonS3Client).context(context).build()
    }

    private val uploadedUrl: String
        get() = getUploadedUrl(nameOfUploadedFile)

    private fun getUploadedUrl(key: String?): String {
        return "https://s3-"+subRegion1.getName()+".amazonaws.com/"+BUCKET_NAME+"/"+key
    }

    private fun initRegion() {
        region1 = getRegionFor(REGION)
        subRegion1 = getRegionFor(SUB_REGION)
    }

    @Throws(UnsupportedEncodingException::class)
    fun deleteImage(): String {
        initRegion()

        val credentialsProvider = CognitoCachingCredentialsProvider(context, IDENTITY_POOL_ID, region1)
        TransferNetworkLossHandler.getInstance(context.applicationContext)

        val amazonS3Client = AmazonS3Client(credentialsProvider, Region.getRegion(subRegion1))
        Thread(Runnable{
            amazonS3Client.deleteObject(BUCKET_NAME, IMAGE_NAME)
        }).start()
        onUploadCompleteListener.onUploadComplete("Success")
        return IMAGE_NAME
    }

    @Throws(UnsupportedEncodingException::class)
    fun uploadImage(image: File): String {
        nameOfUploadedFile = IMAGE_NAME
        val transferObserver = transferUtility.upload(BUCKET_NAME, nameOfUploadedFile, image)

        transferObserver.setTransferListener(object : TransferListener {
            override fun onStateChanged(id: Int, state: TransferState) {
                if (state == TransferState.COMPLETED) {
                    onUploadCompleteListener.onUploadComplete(getUploadedUrl(nameOfUploadedFile))
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
        val transferObserver = transferUtility.download(BUCKET_NAME, nameOfUploadedFile, image)

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

    private fun  getRegionFor(name:String):Regions {
        return when (name) {
            "US_EAST_1" -> Regions.US_EAST_1
            "US_EAST_2" -> Regions.US_EAST_2
            "EU_WEST_1" -> Regions.EU_WEST_1
            "CA_CENTRAL_1" -> Regions.CA_CENTRAL_1
            "CN_NORTH_1" -> Regions.CN_NORTH_1
            "CN_NORTHWEST_1" -> Regions.CN_NORTHWEST_1
            "EU_CENTRAL_1" -> Regions.EU_CENTRAL_1
            "EU_WEST_2" -> Regions.EU_WEST_2
            "EU_WEST_3" -> Regions.EU_WEST_3
            "SA_EAST_1" -> Regions.SA_EAST_1
            "US_WEST_1" -> Regions.US_WEST_1
            "US_WEST_2" -> Regions.US_WEST_2
            "AP_NORTHEAST_1" -> Regions.AP_NORTHEAST_1
            "AP_NORTHEAST_2" -> Regions.AP_NORTHEAST_2
            "AP_SOUTHEAST_1" -> Regions.AP_SOUTHEAST_1
            "AP_SOUTHEAST_2" -> Regions.AP_SOUTHEAST_2
            "AP_SOUTH_1" -> Regions.AP_SOUTH_1
            "ME_SOUTH_1" -> Regions.ME_SOUTH_1
            "AP_EAST_1" -> Regions.AP_EAST_1
            "EU_NORTH_1" -> Regions.EU_NORTH_1
            "US_GOV_EAST_1" -> Regions.US_GOV_EAST_1
            "us-gov-west-1" -> Regions.GovCloud
            else -> Regions.DEFAULT_REGION
        }
    }
}
